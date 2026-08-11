import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:luogo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Default relay URL, overridable at build time with
/// `--dart-define=LUOGO_RELAY_URL=...` and at runtime via the
/// `server-url` setting.
const String kDefaultRelayUrl = String.fromEnvironment(
  'LUOGO_RELAY_URL',
  defaultValue: 'https://relay.luogo.app',
);

/// Wire protocol version shared with the relay. Bump only for changes that
/// break older clients against newer relays (or vice versa); the client
/// refuses to operate against a relay reporting a different version.
const int kProtocolVersion = 1;

/// Normalizes a relay URL for in-app use: WebSocket-style schemes map to
/// their HTTP equivalents because plain HTTP requests (health checks,
/// registration) don't speak the `wss`/`ws` schemes.
String normalizeRelayUrl(String url) {
  if (url.startsWith('wss://')) return 'https://${url.substring(6)}';
  if (url.startsWith('ws://')) return 'http://${url.substring(5)}';
  return url;
}

String resolveRelayUrl(SharedPreferencesWithCache prefs) {
  final String? configured = prefs.getString('server-url');
  if (configured != null && configured.trim().isNotEmpty) {
    return normalizeRelayUrl(configured.trim());
  }
  return normalizeRelayUrl(kDefaultRelayUrl);
}

class RelayException implements Exception {
  final int statusCode;
  final String message;
  RelayException(this.statusCode, this.message);

  @override
  String toString() => 'RelayException($statusCode): $message';
}

/// A group as returned by the relay.
class RelayGroup {
  final String id;
  final String name;
  final String ownerId;
  final int createdAt;
  final int memberCount;

  RelayGroup({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    required this.memberCount,
  });

  factory RelayGroup.fromJson(Map<String, dynamic> json) => RelayGroup(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        ownerId: json['ownerId'] as String? ?? '',
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'createdAt': createdAt,
        'memberCount': memberCount,
      };
}

class RelayMember {
  final String id;
  final String name;
  final int color;
  final String publicKey;

  RelayMember({
    required this.id,
    required this.name,
    required this.color,
    required this.publicKey,
  });

  factory RelayMember.fromJson(Map<String, dynamic> json) => RelayMember(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        color: (json['color'] as num?)?.toInt() ?? 0,
        publicKey: json['publicKey'] as String? ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'color': color, 'publicKey': publicKey};
}

class RelayMessage {
  final String groupId;
  final int seq;
  final int ts;
  final String senderId;
  final Uint8List ciphertext;

  RelayMessage({
    required this.groupId,
    required this.seq,
    required this.ts,
    required this.senderId,
    required this.ciphertext,
  });

  factory RelayMessage.fromJson(String groupId, Map<String, dynamic> json) =>
      RelayMessage(
        groupId: groupId,
        seq: (json['seq'] as num).toInt(),
        ts: (json['ts'] as num).toInt(),
        senderId: json['senderId'] as String? ?? '',
        ciphertext: base64Url.decode(json['ciphertext'] as String),
      );
}

/// Events pushed from the relay, either live over the WebSocket or as a
/// result of a resync.
sealed class RelayEvent {}

class RelayHelloEvent extends RelayEvent {
  final String userId;
  RelayHelloEvent(this.userId);
}

/// The connected relay reports a different wire protocol version than this
/// client. The connection is dropped: the app must not talk to a relay it
/// can't understand.
class RelayVersionMismatchEvent extends RelayEvent {
  final int serverVersion;
  final int clientVersion;
  RelayVersionMismatchEvent({
    required this.serverVersion,
    required this.clientVersion,
  });
}

class RelayMessageEvent extends RelayEvent {
  final RelayMessage message;
  RelayMessageEvent(this.message);
}

class RelayMemberEvent extends RelayEvent {
  final String groupId;
  final String action; // joined | left | renamed
  final String userId;
  final String? name;
  RelayMemberEvent({
    required this.groupId,
    required this.action,
    required this.userId,
    this.name,
  });
}

class RelayPresenceEvent extends RelayEvent {
  final String groupId;
  final List<String> online;
  final String? offline;
  RelayPresenceEvent(
      {required this.groupId, required this.online, this.offline});
}

/// HTTP + WebSocket client for the Luogo relay.
///
/// The relay is a dumb, reliable router: it authenticates clients, tracks
/// group membership, persists a bounded per-group message log with monotonic
/// seq numbers, and fans messages out to connected members. All payloads are
/// encrypted client-side with [GroupCrypto] and opaque to the relay.
class RelayClient {
  final SharedPreferencesWithCache prefs;
  final Box<int> cursorsBox;
  final Box<String> cacheBox;
  String baseUrl;

  static const String _groupsCacheKey = 'groups';
  static String _membersCacheKey(String groupId) => 'members:$groupId';

  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  final StreamController<RelayEvent> _events =
      StreamController<RelayEvent>.broadcast();
  final List<RelayGroup> _groups = [];

  String? _token;
  String? _userId;
  bool _liveRunning = false;
  WebSocketChannel? _ws;
  int _liveGeneration = 0;

  RelayClient({
    required this.prefs,
    required this.cursorsBox,
    required this.cacheBox,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? resolveRelayUrl(prefs) {
    // Seed in-memory state from the last-known cache so offline code paths
    // (resync, peer updates, drawer) have something to work with.
    _groups.addAll(_cachedGroups());
  }

  String get userId => _userId!;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _userId != null;

  Stream<RelayEvent> get events => _events.stream;
  List<RelayGroup> get groups => List.unmodifiable(_groups);

  /// Restores a saved session, or registers a fresh device identity.
  /// [name] and [color] come from the local profile (which may still be
  /// empty at first launch). Never throws on network errors: registration is
  /// retried by [_liveLoop] via [retryConnect] until the relay is reachable.
  Future<void> connect({
    required String name,
    required int color,
    required String publicKey,
  }) async {
    _pendingRegistration = (name: name, color: color, publicKey: publicKey);
    await retryConnect();
  }

  ({String name, int color, String publicKey})? _pendingRegistration;

  /// Attempts to become authenticated: restores a saved session, or
  /// registers the device identity. No-op when already authenticated.
  /// Never throws on network errors.
  Future<void> retryConnect() async {
    if (isAuthenticated) return;
    final String? savedToken = prefs.getString('relay-token');
    final String? savedUserId = prefs.getString('relay-user-id');
    if (savedToken != null && savedUserId != null) {
      // Don't trust a saved session blindly: a token belongs to the relay
      // that issued it, so one carried over from another server (or a stale
      // deployment) is rejected with 401. Re-dialing it forever would keep
      // live updates silently dead, so validate once and fall through to a
      // fresh registration when the relay refuses the session.
      _token = savedToken;
      _userId = savedUserId;
      try {
        await _request('GET', '/api/groups');
        logger.d("Restored relay session for $savedUserId");
        return;
      } on RelayException catch (e) {
        if (e.statusCode != 401 && e.statusCode != 403) {
          logger.d("Session check failed with ${e.statusCode}, keeping it");
          return; // transient relay/network error; retry with the session
        }
        logger.d("Saved relay session rejected (${e.statusCode}), clearing");
        _token = null;
        _userId = null;
        unawaited(prefs.remove('relay-token'));
        unawaited(prefs.remove('relay-user-id'));
      }
    }
    final pending = _pendingRegistration;
    if (pending == null) return;
    try {
      final Map<String, dynamic> body = await _request('POST', '/api/users',
          body: {
            'name': pending.name,
            'color': pending.color,
            'publicKey': pending.publicKey
          });
      final Map<String, dynamic> user = body['user'] as Map<String, dynamic>;
      _userId = user['id'] as String;
      _token = body['token'] as String;
      await prefs.setString('relay-token', _token!);
      await prefs.setString('relay-user-id', _userId!);
      logger.d("Registered new relay identity $userId");
    } catch (e) {
      logger.d("Relay registration failed (will retry): $e");
    }
  }

  /// Updates the profile visible to other group members.
  Future<void> updateProfile({required String name, required int color}) async {
    await _request('PATCH', '/api/users/me',
        body: {'name': name, 'color': color});
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final Uri base = Uri.parse(baseUrl);
    return base.replace(path: path, queryParameters: query);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final HttpClientRequest request =
        await _http.openUrl(method, _uri(path, query));
    request.headers.contentType = ContentType.json;
    if (_token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    }
    if (body != null) {
      request.write(jsonEncode(body));
    }
    final HttpClientResponse response = await request.close();
    final String raw = await response.transform(utf8.decoder).join();
    final Map<String, dynamic>? json =
        raw.isEmpty ? null : jsonDecode(raw) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw RelayException(
        response.statusCode,
        (json?['error'] as String?) ?? 'relay error ${response.statusCode}',
      );
    }
    return json ?? <String, dynamic>{};
  }

  /// Cheap reachability probe used by the background task to fail fast when
  /// the relay (or network) is down instead of burning its execution budget
  /// on per-group connection timeouts.
  Future<bool> isReachable() async {
    try {
      final HttpClientRequest request = await _http
          .getUrl(_uri('/api/health'))
          .timeout(const Duration(seconds: 2));
      final HttpClientResponse response = await request.close();
      await response.drain<void>();
      return response.statusCode < 400;
    } catch (e) {
      logger.d("Relay not reachable: $e");
      return false;
    }
  }

  // --- local cache ------------------------------------------------------

  // Last-known data is kept in the `relay-cache` Hive box so the UI keeps
  // working when the relay is unreachable: member lists and groups fall
  // back to the cached copy instead of throwing.

  Future<void> _cacheGroups(List<RelayGroup> groups) => cacheBox.put(
      _groupsCacheKey, jsonEncode(groups.map((g) => g.toJson()).toList()));

  Future<void> _cacheMembers(String groupId, List<RelayMember> members) =>
      cacheBox.put(_membersCacheKey(groupId),
          jsonEncode(members.map((m) => m.toJson()).toList()));

  List<RelayGroup> _cachedGroups() {
    final String? raw = cacheBox.get(_groupsCacheKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => RelayGroup.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.e("Failed to decode cached groups: $e");
      return [];
    }
  }

  List<RelayMember> _cachedMembers(String groupId) {
    final String? raw = cacheBox.get(_membersCacheKey(groupId));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => RelayMember.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.e("Failed to decode cached members for $groupId: $e");
      return [];
    }
  }

  /// Synchronous read of the last-known member list for [groupId].
  /// Never throws; returns an empty list when nothing is cached yet.
  List<RelayMember> cachedMembers(String groupId) => _cachedMembers(groupId);

  // Patches the cached member list when the relay pushes join/leave events so
  // the offline fallback stays close to reality even without a full refetch.
  Future<void> _updateCachedMembersOnEvent(
      String groupId, String action, String userId) async {
    final List<RelayMember> cached = _cachedMembers(groupId);
    if (cached.isEmpty) return;
    if (action == 'left') {
      cached.removeWhere((m) => m.id == userId);
    } else if (action == 'joined') {
      if (cached.every((m) => m.id != userId)) {
        cached.add(RelayMember(id: userId, name: '', color: 0, publicKey: ''));
      }
    } else {
      return; // renamed and friends — the next successful fetch has details
    }
    await _cacheMembers(groupId, cached);
  }

  // --- groups -----------------------------------------------------------

  Future<List<RelayGroup>> fetchGroups() async {
    try {
      final Map<String, dynamic> body = await _request('GET', '/api/groups');
      final List<dynamic> raw = body['groups'] as List<dynamic>? ?? [];
      final List<RelayGroup> groups = raw
          .map((e) => RelayGroup.fromJson(e as Map<String, dynamic>))
          .toList();
      _groups
        ..clear()
        ..addAll(groups);
      await _cacheGroups(groups);
      return groups;
    } catch (e) {
      logger.d("fetchGroups failed ($e), falling back to cache");
      final List<RelayGroup> cached = _cachedGroups();
      _groups
        ..clear()
        ..addAll(cached);
      return cached;
    }
  }

  Future<RelayGroup> fetchGroup(String groupId) async {
    final Map<String, dynamic> json =
        await _request('GET', '/api/groups/$groupId');
    return RelayGroup.fromJson(json);
  }

  Future<RelayGroup> createGroup(String name) async {
    final Map<String, dynamic> json =
        await _request('POST', '/api/groups', body: {'name': name});
    final RelayGroup group = RelayGroup.fromJson(json);
    _groups.insert(0, group);
    await _cacheGroups(_groups);
    return group;
  }

  Future<void> renameGroup(String groupId, String name) async {
    await _request('PATCH', '/api/groups/$groupId', body: {'name': name});
    final RelayGroup? existing =
        _groups.where((g) => g.id == groupId).firstOrNull;
    if (existing != null) {
      _groups[_groups.indexOf(existing)] = RelayGroup(
        id: existing.id,
        name: name,
        ownerId: existing.ownerId,
        createdAt: existing.createdAt,
        memberCount: existing.memberCount,
      );
      await _cacheGroups(_groups);
    }
  }

  Future<void> leaveGroup(String groupId) async {
    await _request('POST', '/api/groups/$groupId/leave');
    await purgeGroupLocal(groupId);
  }

  /// Owner-only: removes [userId] from [groupId]. The kicked member stops
  /// receiving messages immediately (server-side) and cleans itself up when
  /// its next request comes back 403.
  Future<void> removeMember(String groupId, String userId) async {
    await _request('POST', '/api/groups/$groupId/members/$userId/remove');
    _groups.removeWhere((g) => g.id == groupId);
    await _cacheGroups(_groups);
    await cacheBox.delete(_membersCacheKey(groupId));
  }

  /// Drops every local trace of a group: in-memory list, cached member list
  /// and message cursor. Used when leaving or after being kicked (403).
  Future<void> purgeGroupLocal(String groupId) async {
    _groups.removeWhere((g) => g.id == groupId);
    await _cacheGroups(_groups);
    await cacheBox.delete(_membersCacheKey(groupId));
    await cursorsBox.delete(groupId);
  }

  // --- invites & members ------------------------------------------------

  /// Issues a one-time invite token from the relay. The group key must be
  /// wrapped with it client-side via [GroupCrypto.buildInvitePayload].
  Future<String> createInvite(String groupId) async {
    final Map<String, dynamic> body =
        await _request('POST', '/api/groups/$groupId/invites');
    return body['inviteToken'] as String;
  }

  Future<RelayGroup> joinGroup(String groupId, String inviteToken) async {
    final Map<String, dynamic> json = await _request(
      'POST',
      '/api/groups/$groupId/join',
      body: {'inviteToken': inviteToken},
    );
    final RelayGroup group = RelayGroup.fromJson(json);
    _groups.add(group);
    await _cacheGroups(_groups);
    return group;
  }

  Future<List<RelayMember>> fetchMembers(String groupId) async {
    try {
      final Map<String, dynamic> body =
          await _request('GET', '/api/groups/$groupId/members');
      final List<RelayMember> members =
          (body['members'] as List<dynamic>? ?? [])
              .map((e) => RelayMember.fromJson(e as Map<String, dynamic>))
              .toList();
      await _cacheMembers(groupId, members);
      return members;
    } catch (e) {
      logger.d("fetchMembers failed for $groupId ($e), falling back to cache");
      return _cachedMembers(groupId);
    }
  }

  // --- messages ---------------------------------------------------------

  /// Sends an already-encrypted payload. Returns the server-acked message
  /// (with its group seq) and emits it locally as a RelayMessageEvent.
  Future<RelayMessage> sendMessage(String groupId, Uint8List ciphertext) async {
    final Map<String, dynamic> json = await _request(
      'POST',
      '/api/groups/$groupId/messages',
      body: {'ciphertext': base64Url.encode(ciphertext)},
    );
    final RelayMessage message = RelayMessage.fromJson(groupId, json);
    _applyMessage(message);
    return message;
  }

  /// Fetches messages newer than [afterSeq] (bounded by the server log).
  /// Returns the messages plus the server's current latest seq so callers
  /// can detect cursor desync and paginate past the 500-message limit.
  Future<({List<RelayMessage> messages, int latestSeq})> fetchMessagesAfter(
    String groupId,
    int afterSeq, {
    int limit = 500,
  }) async {
    final Map<String, dynamic> body = await _request(
      'GET',
      '/api/groups/$groupId/messages',
      query: {'afterSeq': '$afterSeq', 'limit': '$limit'},
    );
    return (
      messages: (body['messages'] as List<dynamic>? ?? [])
          .map((e) => RelayMessage.fromJson(groupId, e as Map<String, dynamic>))
          .toList(),
      latestSeq: (body['latestSeq'] as num?)?.toInt() ?? 0,
    );
  }

  /// Pulls everything we've missed since our last cursor and emits it as
  /// RelayMessageEvents. Call this on connect/foreground to stay current.
  ///
  /// Handles two failure modes:
  ///  - the server log was wiped/restored (latestSeq < cursor), which would
  ///    otherwise make every message look "already seen" and deafen the
  ///    client forever;
  ///  - gaps larger than the 500-message fetch limit (paged until caught up).
  Future<void> resyncGroup(String groupId) async {
    int cursor = cursorsBox.get(groupId) ?? 0;
    for (int attempt = 0; attempt < 10; attempt++) {
      final ({List<RelayMessage> messages, int latestSeq}) result =
          await fetchMessagesAfter(groupId, cursor);
      // Server reset or pruned its log below our cursor: restart from 0.
      if (result.latestSeq < cursor) {
        logger.d("resync: server behind local cursor ($cursor), resetting");
        cursor = 0;
        await cursorsBox.put(groupId, 0);
        continue;
      }
      for (final RelayMessage message in result.messages) {
        _applyMessage(message);
      }
      cursor = cursorsBox.get(groupId) ?? cursor;
      if (result.latestSeq <= cursor) {
        return; // caught up
      }
      logger.d("resync: more to fetch (at seq $cursor of ${result.latestSeq})");
    }
  }

  Future<void> resyncAll() async {
    for (final RelayGroup group in _groups) {
      try {
        await resyncGroup(group.id);
      } catch (e) {
        logger.e("resync failed for ${group.id}: $e");
      }
    }
  }

  void _applyMessage(RelayMessage message) {
    final int cursor = cursorsBox.get(message.groupId) ?? 0;
    if (message.seq <= cursor) {
      return; // dedupe (live event arrived before/after a resync)
    }
    cursorsBox.put(message.groupId, message.seq);
    _events.add(RelayMessageEvent(message));
  }

  // --- live connection --------------------------------------------------

  /// Opens the WebSocket and keeps it alive with exponential backoff,
  /// resyncing all groups on every (re)connect.
  void startLive() {
    if (_liveRunning) return;
    _liveRunning = true;
    unawaited(_liveLoop());
  }

  /// Tears down the live connection. Safe to call when already stopped.
  void stopLive() {
    _liveRunning = false;
    _liveGeneration++; // invalidate any in-flight _liveLoop
    _ws?.sink.close();
    _ws = null;
  }

  /// Points this client at a different relay: stops the current connection,
  /// forgets the old relay's identity (tokens are per-server), and
  /// reconnects, registering a fresh identity on the new relay. The saved
  /// 'server-url' pref must already be updated by the caller.
  Future<void> rebindRelay(String newBaseUrl) async {
    stopLive();
    baseUrl = normalizeRelayUrl(newBaseUrl.trim());
    _token = null;
    _userId = null;
    // Wait for the stale session to be gone before the live loop restarts,
    // otherwise retryConnect could restore the old relay's token.
    await prefs.remove('relay-token');
    await prefs.remove('relay-user-id');
    startLive();
  }

  Future<void> _liveLoop() async {
    // Generation guard: when a rebind swaps relays, any still-running loop
    // from the old relay exits instead of fighting the new connection.
    final int gen = _liveGeneration;
    int backoffSeconds = 1;
    while (_liveRunning && gen == _liveGeneration) {
      try {
        // Make sure we're authenticated before opening the WebSocket.
        if (!isAuthenticated) {
          await retryConnect();
        }
        if (!isAuthenticated) {
          logger.d("Relay not reachable yet, waiting to retry...");
        } else {
          final Uri base = Uri.parse(baseUrl);
          final Uri uri = base.replace(
            scheme: base.scheme == 'https' ? 'wss' : 'ws',
            path: '/ws',
            queryParameters: {'token': _token},
          );
          final WebSocketChannel channel = WebSocketChannel.connect(uri);
          if (gen != _liveGeneration) {
            // Superseded mid-connect (rebind); don't adopt this socket.
            channel.sink.close();
            break;
          }
          _ws = channel;
          await channel.ready;
          backoffSeconds = 1;
          logger.d("Relay WebSocket connected");
          // Catch up on anything missed while offline.
          await resyncAll();
          await for (final dynamic raw in channel.stream) {
            final Map<String, dynamic> evt =
                jsonDecode(raw as String) as Map<String, dynamic>;
            _handleServerEvent(evt);
          }
        }
      } catch (e) {
        logger.e("Relay WebSocket error: $e");
      } finally {
        if (gen == _liveGeneration) _ws = null;
      }
      if (!_liveRunning || gen != _liveGeneration) break;
      await Future<void>.delayed(Duration(seconds: backoffSeconds));
      if (backoffSeconds < 30) backoffSeconds *= 2;
    }
  }

  void _handleServerEvent(Map<String, dynamic> evt) {
    switch (evt['type']) {
      case 'hello':
        // A pre-version relay omits protocolVersion; treat that as 0.
        final int serverVersion = evt['protocolVersion'] as int? ?? 0;
        _events.add(RelayHelloEvent(evt['userId'] as String? ?? ''));
        if (serverVersion != kProtocolVersion) {
          logger.e(
              "Relay protocol mismatch: client=$kProtocolVersion server=$serverVersion");
          _events.add(RelayVersionMismatchEvent(
            serverVersion: serverVersion,
            clientVersion: kProtocolVersion,
          ));
          stopLive();
        }
      case 'message':
        final RelayMessage message =
            RelayMessage.fromJson(evt['groupId'] as String, evt);
        _applyMessage(message);
      case 'member':
        _events.add(RelayMemberEvent(
          groupId: evt['groupId'] as String,
          action: evt['action'] as String? ?? '',
          userId: evt['userId'] as String? ?? '',
          name: evt['name'] as String?,
        ));
        _updateCachedMembersOnEvent(
          evt['groupId'] as String,
          evt['action'] as String? ?? '',
          evt['userId'] as String? ?? '',
        );
      case 'presence':
        _events.add(RelayPresenceEvent(
          groupId: evt['groupId'] as String,
          online: (evt['online'] as List<dynamic>? ?? [])
              .map((e) => e as String)
              .toList(),
          offline: evt['offline'] as String?,
        ));
      default:
        logger.d("Unknown relay event: $evt");
    }
  }

  bool get isLiveRunning => _liveRunning;

  void dispose() {
    stopLive();
    _events.close();
    _http.close(force: true);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
