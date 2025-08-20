import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'ask_for_location_state.dart';

class AskForLocationCubit extends Cubit<AskForLocationState> {
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;
  AskForLocationCubit({
    required this.prefs,
    required this.locationService,
  }) : super(AskForLocationInitial());

  static AskForLocationCubit get(context) => BlocProvider.of(context);

  Future<void> requestPerms() async {
    await locationService.askForLocationPermissions();
    locationService.startPeriodicUpdates();
    emit(AskForLocationApproved());
  }

  void denyRequestPerms() {
    prefs.setBool("location-perms-denied-persist", true);
    emit(AskForLocationDenied());
  }
}
