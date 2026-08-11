import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:luogo/main.dart';
import 'package:luogo/services/relay_client.dart';

/// Outcome of a relay reachability probe.
enum RelayProbeStatus {
  /// The relay answered a health check with a compatible protocol version.
  online,

  /// Nothing reachable answered, or the URL is not a plausible relay.
  offline,

  /// The relay answered but speaks a different wire protocol version.
  versionMismatch,
}

class RelayProbeResult {
  final RelayProbeStatus status;
  final int serverProtocolVersion;

  const RelayProbeResult(this.status, this.serverProtocolVersion);

  const RelayProbeResult.online(int serverProtocolVersion)
      : this(RelayProbeStatus.online, serverProtocolVersion);
  const RelayProbeResult.offline()
      : this(RelayProbeStatus.offline, 0);
  const RelayProbeResult.versionMismatch(int serverProtocolVersion)
      : this(RelayProbeStatus.versionMismatch, serverProtocolVersion);
}

/// Single shared reachability probe used by the Settings page and the
/// profile-creation server dialog, so both surfaces make the same call and
/// interpret the result the same way.
///
/// Fetches `GET /api/health` on the URL (normalized with
/// [normalizeRelayUrl]) with a hard timeout; the relay reports its wire
/// protocol version there, which is compared against [kProtocolVersion].
Future<RelayProbeResult> probeRelayHealth(String url) async {
  final String normalized = normalizeRelayUrl(url.trim());
  final Uri uri = Uri.parse(normalized).replace(path: '/api/health');
  try {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    try {
      final HttpClientRequest request =
          await client.getUrl(uri).timeout(const Duration(seconds: 3));
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 3));
      final String body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 3));
      if (response.statusCode >= 400) {
        return const RelayProbeResult.offline();
      }
      final int serverVersion =
          (jsonDecode(body) as Map<String, dynamic>)['protocolVersion'] as int? ??
              0;
      if (serverVersion != kProtocolVersion) {
        return RelayProbeResult.versionMismatch(serverVersion);
      }
      return RelayProbeResult.online(serverVersion);
    } finally {
      client.close(force: true);
    }
  } catch (e) {
    logger.d("Relay probe failed for $normalized: $e");
    return const RelayProbeResult.offline();
  }
}