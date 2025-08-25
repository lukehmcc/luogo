import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/init_router/init_router_state.dart';
import 'package:luogo/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Cubit class for managing the initialization router state, checking if the user has been initialized via shared preferences.
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) => InitRouterCubit(prefs: yourSharedPreferencesInstance),
///   child: YourInitRouterWidget(),
/// )
/// ```
class InitRouterCubit extends Cubit<InitRouterState> {
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;

  InitRouterCubit({
    required this.prefs,
    required this.locationService,
  }) : super(InitRouterInitial());

  Future<void> getRoute() async {
    // Emit that it is loading
    emit(InitRouterLoading());
    // This is here because this funciton is too fast, so the changes don't register
    // unless a frame is skipped
    await Future.delayed(Duration.zero);
    // Now check if prefs have been set
    final bool hasColor = prefs.containsKey('color');
    final bool hasName = prefs.containsKey('name');
    // Check if we have location perms
    bool locationPerms = await locationService.checkLocationPermissions();
    bool locationPermsDeniedPersisted =
        prefs.getBool("location-perms-have-been-requested") ?? false;
    if (hasColor && hasName) {
      emit(InitRouterSuccess(route: RouteType.home));
    } else if (!locationPerms && !locationPermsDeniedPersisted) {
      emit(InitRouterSuccess(route: RouteType.locationPerms));
    } else {
      emit(InitRouterSuccess(route: RouteType.login));
    }
  }
}
