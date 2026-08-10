import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:hive_ce/hive.dart';
import 'package:luogo/main.dart';

/// Client-side group encryption. Each group gets a random 256-bit key
/// (XChaCha20-Poly1305) generated on the creating device and shared to new
/// members only through the out-of-band invite payload. The relay server
/// routes ciphertext and never sees the key or the plaintext.
class GroupCrypto {
  /// Box of groupId -> base64url-encoded group key.
  final Box<String> keysBox;

  GroupCrypto(this.keysBox);

  static const int keyLength = 32;

  static final Random _random = Random.secure();
  static final Xchacha20 _cipher = Xchacha20.poly1305Aead();
  static final Ed25519 _ed25519 = Ed25519();

  Uint8List? _keyFor(String groupId) {
    final String? stored = keysBox.get(groupId);
    if (stored == null) return null;
    try {
      return base64Url.decode(stored);
    } catch (e) {
      logger.e("Failed to decode group key: $e");
      return null;
    }
  }

  /// Returns the group key, generating and persisting one if absent.
  Future<Uint8List> keyFor(String groupId) async {
    final Uint8List? existing = _keyFor(groupId);
    if (existing != null) return existing;
    final Uint8List key = generateKey();
    await keysBox.put(groupId, base64Url.encode(key));
    return key;
  }

  /// Stores a key obtained from an invite payload.
  Future<void> storeKey(String groupId, Uint8List key) async {
    await keysBox.put(groupId, base64Url.encode(key));
  }

  bool hasKey(String groupId) => _keyFor(groupId) != null;

  /// Forgets a group key locally (leave / kicked).
  Future<void> deleteKey(String groupId) async {
    await keysBox.delete(groupId);
  }

  /// Encrypts a JSON map payload for a group.
  Future<Uint8List> encrypt(String groupId, Map<String, dynamic> payload) {
    return _encryptWithKey(_keyFor(groupId), payload);
  }

  Future<Uint8List> _encryptWithKey(
      Uint8List? key, Map<String, dynamic> payload) {
    if (key == null) {
      throw StateError("no group key for group");
    }
    final Uint8List nonce = _randomNonce(24);
    return _cipher
        .encrypt(
          utf8.encode(jsonEncode(payload)),
          secretKey: SecretKey(key),
          nonce: nonce,
        )
        .then((SecretBox box) => box.concatenation());
  }

  /// Decrypts a payload. Returns null on auth failure or missing key.
  Future<Map<String, dynamic>?> decrypt(
      String groupId, Uint8List ciphertext) async {
    final Uint8List? key = _keyFor(groupId);
    if (key == null) return null;
    try {
      final SecretBox box = SecretBox.fromConcatenation(
          ciphertext, nonceLength: 24, macLength: 16);
      final List<int> clear =
          await _cipher.decrypt(box, secretKey: SecretKey(key));
      return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    } catch (e) {
      logger.e("Failed to decrypt message: $e");
      return null;
    }
  }

  static Uint8List generateKey() {
    final Uint8List key = Uint8List(keyLength);
    for (int i = 0; i < keyLength; i++) {
      key[i] = _random.nextInt(256);
    }
    return key;
  }

  static Uint8List _randomNonce(int length) {
    final Uint8List nonce = Uint8List(length);
    for (int i = 0; i < length; i++) {
      nonce[i] = _random.nextInt(256);
    }
    return nonce;
  }

  // --- device identity (Ed25519) ---------------------------------------

  /// Loads the persisted device private key or creates and persists one.
  /// Returns the 32-byte seed, plus the base64url public key for registration.
  static Future<({Uint8List privateKey, String publicKey})>
      loadOrCreateIdentity(Box<dynamic> dataBox) async {
    const String key = 'relay_identity';
    if (dataBox.containsKey(key)) {
      final Map<dynamic, dynamic> data = dataBox.get(key) as Map;
      return (
        privateKey: base64Url.decode(data['privateKey'] as String),
        publicKey: data['publicKey'] as String,
      );
    }
    final SimpleKeyPair keyPair = await _ed25519.newKeyPair();
    final SimplePublicKey publicKey = await keyPair.extractPublicKey();
    final Uint8List privateKey =
        Uint8List.fromList(await keyPair.extractPrivateKeyBytes());
    final String publicKeyString = base64Url.encode(publicKey.bytes);
    await dataBox.put(key, {
      'privateKey': base64Url.encode(privateKey),
      'publicKey': publicKeyString,
    });
    return (privateKey: privateKey, publicKey: publicKeyString);
  }

  // --- invite payload ---------------------------------------------------

  /// Wire format for the QR/copy invite. The group key rides in this payload
  /// only; it is never sent to the relay.
  static String buildInvitePayload({
    required String groupId,
    required String inviteToken,
    required Uint8List groupKey,
  }) {
    return 'luogo-invite-key: v1:$groupId:$inviteToken:${base64Url.encode(groupKey)}';
  }

  static ({String groupId, String inviteToken, Uint8List groupKey})?
      parseInvitePayload(String raw) {
    if (!raw.startsWith('luogo-invite-key: ')) return null;
    final List<String> parts = raw.substring(18).split(':');
    if (parts.length != 4 || parts[0] != 'v1') return null;
    final Uint8List groupKey;
    try {
      groupKey = base64Url.decode(parts[3]);
    } catch (e) {
      return null;
    }
    if (groupKey.length != keyLength) return null;
    return (
      groupId: parts[1],
      inviteToken: parts[2],
      groupKey: groupKey,
    );
  }
}
