import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/init_router/init_router_cubit.dart';
import 'package:luogo/cubit/init_router/init_router_state.dart';
import 'package:luogo/cubit/main/main_cubit.dart';
import 'package:luogo/cubit/main/main_state.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/view/page/create_profile.dart';
import 'package:luogo/view/page/home.dart';
import 'package:luogo/view/page/silly_progress_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InitRouterPage extends StatelessWidget {
  const InitRouterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MainCubit, MainState>(builder: (context, mainState) {
      return switch (mainState) {
        MainStateInitial() => const SillyCircularProgressIndicator(),
        MainStateLoading() => const SillyCircularProgressIndicator(),
        MainStateError(:final message) => Center(child: Text(message)),
        MainStateLightInitialized(:final prefs, :final locationService) =>
          _buildInitRouterPage(context, prefs, locationService),
        MainStateHeavyInitialized(:final prefs, :final locationService) =>
          _buildInitRouterPage(context, prefs, locationService),
      };
    });
  }

  Widget _buildInitRouterPage(BuildContext context, SharedPreferences prefs,
      LocationService locationService) {
    return BlocProvider(
      create: (context) => InitRouterCubit(prefs: prefs)..checkPreferences(),
      child: BlocListener<InitRouterCubit, InitRouterState>(
        listener: (context, state) {
          if (state is InitRouterSuccess) {
            _navigateBasedOnRoute(context, state.route, prefs, locationService);
          }
        },
        child: SillyCircularProgressIndicator(),
      ),
    );
  }

  void _navigateBasedOnRoute(BuildContext context, RouteType route,
      SharedPreferences prefs, LocationService locationService) {
    final page = route == RouteType.home
        ? HomePage(
            prefs: prefs,
            locationService: locationService,
          )
        : CreateProfilePage(
            prefs: prefs,
            locationService: locationService,
          );

    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (context) => page), (route) => false);
  }
}
