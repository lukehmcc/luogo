import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:luogo/cubit/main/main_state.dart';
import 'package:luogo/hive/hive_registrar.g.dart';
import 'package:luogo/main.dart';
import 'package:luogo/services/group_crypto.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:luogo/services/relay_setup.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

/// A Cubit class for managing the main application state.
///
/// Initializes shared preferences, Hive, the relay client, group crypto and
/// the location service, then hands everything to the UI.
class MainCubit extends Cubit<MainState> {
  MainCubit() : super(MainStateInitial());

  late final SharedPreferencesWithCache prefs;
  late final LocationService locationService;
  late final RelayClient relayClient;
  late final GroupCrypto crypto;

  Future<void> initializeApp() async {
    try {
      emit(MainStateLoading());

      // Quick dependencies
      prefs = await SharedPreferencesWithCache.create(
          cacheOptions: SharedPreferencesWithCacheOptions());

      final Directory dir = await getApplicationSupportDirectory();
      Hive
        ..init(path.join(dir.path, 'hive'))
        ..registerAdapters();

      locationService = LocationService(prefs: prefs);
      await locationService.init();
      // register it here so the background task can grab it; do this before
      // the slow permission check so in-app background events hit the fast path
      GetIt.I.registerSingleton<LocationService>(locationService);
      await locationService.startPeriodicUpdates(intervalSeconds: 5);

      // Relay + crypto (fast, no native init)
      final relaySetup = await initRelayAndCrypto(prefs);
      crypto = relaySetup.crypto;
      relayClient = relaySetup.relay;

      locationService.setRelayClient(relayClient, crypto);
      relayClient.startLive();

      emit(MainStateInitialized(
        prefs: prefs,
        locationService: locationService,
        relayClient: relayClient,
        crypto: crypto,
      ));
    } catch (e) {
      logger.e('Initialization error: $e');
      emit(MainStateError(e.toString()));
    }
  }
}
