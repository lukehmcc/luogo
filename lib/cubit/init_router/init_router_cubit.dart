import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/init_router/init_router_state.dart';
import 'package:luogo/main.dart';

/// Simple logic that checks if user has been initialized
class InitRouterCubit extends Cubit<InitRouterState> {
  InitRouterCubit() : super(InitRouterInitial());

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
