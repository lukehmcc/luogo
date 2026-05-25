import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'ask_for_location_state.dart';

class AskForLocationCubit extends Cubit<AskForLocationState> {
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;
  Timer? _timer;

  AskForLocationCubit({
    required this.prefs,
    required this.locationService,
  }) : super(AskForLocationInitial()) {
    // Start periodic re-check in case user enables in settings
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      bool locationPerms = await locationService.checkLocationPermissions();
      if (locationPerms) {
        timer.cancel();
        requestPerms();
      }
    });
  }

  static AskForLocationCubit get(context) => BlocProvider.of(context);

  Future<void> requestPerms() async {
    // Check if we already have perms before asking again
    bool hasPerms = await locationService.checkLocationPermissions();
    if (!hasPerms) {
      await locationService.askForLocationPermissions();
    }
    
    locationService.startPeriodicUpdates();
    prefs.setBool("location-perms-have-been-requested", true);
    emit(AskForLocationApproved());
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
