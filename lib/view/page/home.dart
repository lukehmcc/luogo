import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/groups_drawer/groups_drawer_cubit.dart';
import 'package:luogo/cubit/home/home_cubit.dart';
import 'package:luogo/cubit/home/home_state.dart';
import 'package:luogo/cubit/main/main_cubit.dart';
import 'package:luogo/cubit/main/main_state.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/view/page/map.dart';
import 'package:luogo/view/page/silly_progress_indicator.dart';
import 'package:luogo/view/widgets/map_overlay.dart';
import 'package:luogo/view/widgets/mls_groups_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatelessWidget {
  final SharedPreferences prefs;
  final LocationService locationService;

  const HomePage(
      {super.key, required this.prefs, required this.locationService});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
        // Gotta provide both the drawer and home page overlay so they could be listened
        providers: [
          BlocProvider<GroupsDrawerCubit>(
            create: (BuildContext context) => GroupsDrawerCubit(),
          ),
          BlocProvider<HomeCubit>(
            create: (BuildContext context) => HomeCubit(),
          )
        ],
        child: Scaffold(
          appBar: AppBar(backgroundColor: Colors.transparent),
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // Map loads immediately in background
              MapView(
                locationService: locationService,
                prefs: prefs,
              ),
              // Only show the overlay if the group doesn't exist
              BlocBuilder<HomeCubit, HomeState>(
                builder: (context, homeState) {
                  final homeCubit = context.read<HomeCubit>();
                  // since you can only see this if a group is selected,
                  // s5messenger should always be populated
                  final mainCubit = context.read<MainCubit>();
                  if (homeCubit.group != null) {
                    return MapOverlay(
                      group: homeCubit.group,
                      s5messenger: mainCubit.s5messenger,
                    );
                  }
                  return Container();
                },
              ),
            ],
          ),
          drawer: BlocBuilder<MainCubit, MainState>(
            // Drawer waits for s5messenger
            builder: (context, mainState) {
              // Make sure to update the cubit
              if (mainState is MainStateHeavyInitialized) {
                context
                    .read<GroupsDrawerCubit>()
                    .setS5Messenger(mainState.s5messenger);
              }
              return switch (mainState) {
                MainStateHeavyInitialized(:final s5messenger) => GroupsDrawer(
                    s5messenger: s5messenger,
                  ),
                _ => const Drawer(
                    // Show loading drawer
                    child: SillyCircularProgressIndicator(),
                  ),
              };
            },
          ),
        ));
  }
}
