import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:luogo/cubit/main/main_state.dart';
import 'package:luogo/hive/hive_registrar.g.dart';
import 'package:luogo/main.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/utils/s5_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:s5/s5.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

/// A Cubit class for managing the main application state.
///
/// It initializes dependencies like S5, S5Messenger, shared
/// preferences, and location services.
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) => MainCubit(),
///   child: YourMainWidget(),
/// )
/// ```
class MainCubit extends Cubit<MainState> {
  MainCubit() : super(MainStateInitial());

  late final S5 s5;
  late final S5Messenger s5messenger;
  late final SharedPreferencesWithCache prefs;
  late final LocationService locationService;

  Future<void> initializeApp() async {
    try {
      // Emit loading
      emit(MainStateLoading());

      // Do the quick dependencies
      prefs = await SharedPreferencesWithCache.create(
          cacheOptions: SharedPreferencesWithCacheOptions());

      // Begin the rust stuff
      await RustLib.init();
      final Directory dir = await getApplicationSupportDirectory();
      Hive
        ..init(path.join(dir.path, 'hive'))
        ..registerAdapters();
      locationService = LocationService(prefs: prefs);
      await locationService.init();
      bool sucsess =
          await locationService.startPeriodicUpdates(intervalSeconds: 5);
      // This shuld only fail if location permissions haven't been granted, if that happens
      // emit so the app can push to the correct page
      if (sucsess == false) {
        emit(MainStateNeedsLocationPermission(
          prefs: prefs,
          locationService: locationService,
        ));
      }
      // register it here so I can grab for the background task later
      GetIt.I.registerSingleton<LocationService>(locationService);
      emit(MainStateLightInitialized(
        prefs: prefs,
        locationService: locationService,
      )); // Let the UI build on the quick deps

      // Do the slower dependeinces
      s5 = await S5.create(
        initialPeers: [
          prefs.getString('s5-node') ?? '', // put the users s5 node first
          'wss://z2DeVYsXdq3Rgt8252LRwNnreAtsGr3BN6FPc6Hvg6dTtRk@s5.jptr.tech/s5/p2p',
          'wss://z2Das8aEF7oNoxkcrfvzerZ1iBPWfm6D7gy3hVE4ALGSpVB@node.sfive.net/s5/p2p',
          'wss://z2DdbxV4xyoqWck5pXXJdVzRnwQC6Gbv6o7xDvyZvzKUfuj@s5.vup.dev/s5/p2p',
          'wss://z2DWuWNZcdSyZLpXFK2uCU3haaWMXrDAgxzv17sDEMHstZb@s5.garden/s5/p2p',
        ],
        logger: SilentLogger(),
        persistFilePath: path.join(
            (await getApplicationDocumentsDirectory()).path, 'persist.json'),
      );
      s5messenger = S5Messenger();
      await s5messenger.init(s5);
      emit(MainStateHeavyInitialized(
        s5: s5,
        s5messenger: s5messenger,
        prefs: prefs,
        locationService: locationService,
      ));
    } catch (e) {
      logger.e('Initialization error: $e');
      emit(MainStateError(e.toString()));
    }
  }
}
