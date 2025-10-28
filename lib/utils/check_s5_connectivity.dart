import 'package:flutter/foundation.dart';
import 'package:lib5/registry.dart';
import 'package:luogo/main.dart';
import 'package:s5/s5.dart';

// Quick function to check connectivity
Future<bool> checkS5Online(S5 s5) async {
  final Uint8List testKey = Uint8List(32);
  for (int i = 0; i < 32; i++) {
    testKey[i] = i;
  }
  try {
    final Uint8List testData = Uint8List.fromList([1, 2, 3]);
    final KeyPairEd25519 kp =
        await s5.api.crypto.newKeyPairEd25519(seed: testKey);
    int revision = 1;

    // grab it first to check revison
    SignedRegistryEntry? res = await s5.api.registryGet(kp.publicKey);
    if (res != null) {
      revision = res.revision + 1;
    }

    // set it
    await s5.api.registrySet(
      await signRegistryEntry(
        kp: kp,
        data: testData,
        revision: revision,
        crypto: s5.api.crypto,
      ),
    );
    // then grab and test
    res = await s5.api.registryGet(kp.publicKey);
    if (res != null && listEquals(res.data, testData)) {
      return true;
    } else {
      logger.d("Data mismatch, expected: $testData, got: ${res?.data}");
      return false;
    }
  } catch (e) {
    logger.d("Failed due to error $e");
    return false;
  }
}
