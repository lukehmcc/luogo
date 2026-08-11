import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/services/battery_optimization.dart';
import 'package:luogo/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'ask_for_location_state.dart';

class AskForLocationCubit extends Cubit<AskForLocationState> {
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;
  late final AppLifecycleListener _lifecycleListener;

  AskForLocationCubit({
    required this.prefs,
    required this.locationService,
  }) : super(const AskForLocationInitial(
          locationGranted: false,
          batteryExempt: false,
          checking: true,
        )) {
    _lifecycleListener =
        AppLifecycleListener(onResume: () => refreshStatus());
    // Re-check battery status when the user returns from the Android settings
    // screen (a non-widget listener, so the page stays widget-free).
    refreshStatus();
  }

  static AskForLocationCubit get(context) => BlocProvider.of(context);

  /// Reads the actual platform permission/battery state into the cubit state.
  /// Also used on app resume so tiles flip X -> check once granted.
  Future<void> refreshStatus() async {
    if (isClosed) return;
    emit(const AskForLocationInitial(
      locationGranted: false,
      batteryExempt: false,
      checking: true,
    ));
    final bool locationGranted =
        await locationService.checkLocationPermissions();
    final bool batteryExempt = await BatteryOptimizationService.isExempt();
    if (isClosed) return;
    emit(AskForLocationInitial(
      locationGranted: locationGranted,
      batteryExempt: batteryExempt,
    ));
  }

  Future<void> requestLocation() async {
    if (!await locationService.checkLocationPermissions()) {
      await locationService.askForLocationPermissions();
    }
    await refreshStatus();
  }

  Future<void> requestBattery() async {
    await BatteryOptimizationService.requestExemption();
    await refreshStatus();
  }

  Future<void> continueToApp() async {
    await locationService.startPeriodicUpdates();
    await prefs.setBool("location-perms-have-been-requested", true);
    emit(AskForLocationApproved());
  }

  @override
  Future<void> close() {
    _lifecycleListener.dispose();
    return super.close();
  }
}