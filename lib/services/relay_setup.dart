import 'package:hive_ce/hive.dart';
import 'package:luogo/services/group_crypto.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens the relay-backed Hive boxes, loads (or creates) the device identity
/// and connects the [RelayClient]. Shared by the foreground [MainCubit] and
/// the background task so both paths stay in sync.
Future<({RelayClient relay, GroupCrypto crypto})> initRelayAndCrypto(
  SharedPreferencesWithCache prefs,
) async {
  final Box<int> cursorsBox = await Hive.openBox<int>('relay-cursors');
  final Box<String> keysBox = await Hive.openBox<String>('relay-group-keys');
  final Box<String> cacheBox = await Hive.openBox<String>('relay-cache');
  final Box<dynamic> dataBox = await Hive.openBox('relay-data');

  final RelayClient relay = RelayClient(
      prefs: prefs, cursorsBox: cursorsBox, cacheBox: cacheBox);
  final identity = await GroupCrypto.loadOrCreateIdentity(dataBox);
  await relay.connect(
    name: prefs.getString('name') ?? '',
    color: prefs.getInt('color') ?? 0,
    publicKey: identity.publicKey,
  );

  return (relay: relay, crypto: GroupCrypto(keysBox));
}
