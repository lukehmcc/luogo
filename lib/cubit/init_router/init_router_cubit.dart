import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/init_router/init_router_state.dart';
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

  InitRouterCubit({required this.prefs}) : super(InitRouterInitial());

  Future<void> checkPreferences() async {
    // Emit that it is loading
    emit(InitRouterLoading());
    // This is here because this funciton is too fast, so the changes don't register
    // unless a frame is skipped
    await Future.delayed(Duration.zero);
    // Now check if prefs have been set
    final bool hasColor = prefs.containsKey('color');
    final bool hasName = prefs.containsKey('name');
    if (hasColor && hasName) {
      emit(InitRouterSuccess(route: RouteType.home));
    } else {
      emit(InitRouterSuccess(route: RouteType.login));
    }
  }
}
