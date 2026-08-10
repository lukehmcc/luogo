import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/groups_drawer/groups_drawer_cubit.dart';
import 'package:luogo/cubit/home/home_cubit.dart';
import 'package:luogo/cubit/home/home_state.dart';
import 'package:luogo/cubit/main/main_cubit.dart';
import 'package:luogo/cubit/main/main_state.dart';
import 'package:luogo/cubit/map/map_cubit.dart';
import 'package:luogo/cubit/map/map_overlay/map_overlay_cubit.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/view/page/map.dart';
import 'package:luogo/view/page/map/map_overlay.dart';
import 'package:luogo/view/page/home/groups_drawer.dart';
import 'package:luogo/view/widgets/silly_progress_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatelessWidget {
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;

  const HomePage({
    super.key,
    required this.prefs,
    required this.locationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
        // Gotta provide both the drawer and home page overlay so they could be listened
        providers: [
          BlocProvider<GroupsDrawerCubit>(
            create: (BuildContext context) => GroupsDrawerCubit(
              locationService: locationService,
            ),
          ),
          BlocProvider<HomeCubit>(
            create: (BuildContext context) => HomeCubit(),
          )
        ],
        child: Scaffold(
          body: Stack(
            children: [
              // Map loads immediately in background
              MapView(
                locationService: locationService,
                prefs: prefs,
              ),

              ScaffoldDrawerButton(),

              // Only show the overlay if a group is selected
              BlocBuilder<HomeCubit, HomeState>(
                builder: (context, homeState) {
                  final homeCubit = context.read<HomeCubit>();
                  // since you can only see this if a group is selected,
                  // the relay should always be populated
                  final mainCubit = context.read<MainCubit>();
                  // Now read to check if init finished
                  return BlocSelector<MainCubit, MainState, bool>(
                    selector: (MainState state) =>
                        state is MainStateInitialized,
                    builder: (context, isInitialized) {
                      if (isInitialized) {
                        final mainState = mainCubit.state as MainStateInitialized;
                        return BlocProvider<MapOverlayCubit>(
                            create: (BuildContext context) => MapOverlayCubit(
                                  selectedGroup: homeCubit.group,
                                  relayClient: mainState.relayClient,
                                  locationService: locationService,
                                  mapController:
                                      context.read<MapCubit>().mapController,
                                  symbolIDMap:
                                      context.read<MapCubit>().symbolIDMap,
                                ),
                            child: MapOverlay(
                              groupInfo: homeCubit.group,
                              relayClient: mainState.relayClient,
                              crypto: mainState.crypto,
                              locationService: locationService,
                              prefs: prefs,
                            ));
                      } else {
                        return Container();
                      }
                    },
                  );
                },
              ),
            ],
          ),
          drawer: BlocBuilder<MainCubit, MainState>(
            // Drawer waits for the relay
            builder: (context, mainState) {
              // Make sure to update the cubit
              if (mainState is MainStateInitialized) {
                context
                    .read<GroupsDrawerCubit>()
                    .setRelayClient(mainState.relayClient, mainState.crypto);
              }
              return switch (mainState) {
                MainStateInitialized(:final relayClient) => GroupsDrawer(
                    relayClient: relayClient,
                    prefs: prefs,
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

class ScaffoldDrawerButton extends StatelessWidget {
  const ScaffoldDrawerButton({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.all(5),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).cardColor.withValues(alpha: .5),
            ),
            child: IconButton(
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
                icon: Icon(Icons.menu)),
          ),
        ),
      ),
    );
  }
}
