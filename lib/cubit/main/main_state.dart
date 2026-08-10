import 'package:luogo/services/location_service.dart';
import 'package:luogo/services/group_crypto.dart';
import 'package:luogo/services/relay_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

sealed class MainState {}

class MainStateInitial extends MainState {}

class MainStateLoading extends MainState {}

/// Everything needed by the UI is ready: profile routing, the relay
/// connection and live subscription are all handled here.
class MainStateInitialized extends MainState {
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;
  final RelayClient relayClient;
  final GroupCrypto crypto;

  MainStateInitialized({
    required this.prefs,
    required this.locationService,
    required this.relayClient,
    required this.crypto,
  });
}

class MainStateError extends MainState {
  final String message;
  MainStateError(this.message);
}
