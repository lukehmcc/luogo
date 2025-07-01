import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/groups_drawer/groups_drawer_cubit.dart';
import 'package:luogo/cubit/main/main_cubit.dart';
import 'package:luogo/cubit/main/main_state.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/view/page/map.dart';
import 'package:luogo/view/page/silly_progress_indicator.dart';
import 'package:luogo/view/widgets/mls_groups_drawer.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatelessWidget {
  final SharedPreferences prefs;
  final LocationService locationService;

  const HomePage(
      {super.key, required this.prefs, required this.locationService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: MapView(
        // Map loads immediately
        locationService: locationService,
        prefs: prefs,
      ),
      drawer: BlocBuilder<MainCubit, MainState>(
        // Drawer waits for s5messenger
        builder: (context, mainState) {
          return switch (mainState) {
            MainStateHeavyInitialized(:final s5messenger) =>
              _buildGroupsDrawer(s5messenger),
            _ => const Drawer(
                // Show loading drawer
                child: SillyCircularProgressIndicator(),
              ),
          };
        },
      ),
    );
  }

  Widget _buildGroupsDrawer(S5Messenger s5messenger) {
    return BlocProvider(
      create: (context) => GroupsDrawerCubit(s5messenger: s5messenger),
      child: GroupsDrawer(
        s5messenger: s5messenger,
      ),
    );
  }
}
