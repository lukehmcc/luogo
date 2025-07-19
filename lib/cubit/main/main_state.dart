import 'package:luogo/services/location_service.dart';
import 'package:s5/s5.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:shared_preferences/shared_preferences.dart';

sealed class MainState {}

class MainStateInitial extends MainState {}

class MainStateLoading extends MainState {}

/// The fast to init dependencies can be emitted quickly here
class MainStateLightInitialized extends MainState {
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;

  MainStateLightInitialized({
    required this.prefs,
    required this.locationService,
  });
}

/// The slower to init dependencies can be emitted later here
class MainStateHeavyInitialized extends MainState {
  final S5 s5;
  final S5Messenger s5messenger;
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;

  MainStateHeavyInitialized({
    required this.s5,
    required this.s5messenger,
    required this.prefs,
    required this.locationService,
  });
}

class MainStateError extends MainState {
  final String message;
  MainStateError(this.message);
}
