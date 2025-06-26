import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:luogo/cubit/home/home_cubit.dart';
import 'package:luogo/cubit/home/home_state.dart';
import 'package:luogo/cubit/main/main_cubit.dart';
import 'package:luogo/cubit/main/main_state.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/view/page/map.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatelessWidget {
  final SharedPreferences prefs;
  final Logger logger;
  final LocationService locationService;

  const HomePage(
      {super.key,
      required this.prefs,
      required this.logger,
      required this.locationService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: MapView(
        // Map loads immediately
        locationService: locationService,
        logger: logger,
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
                child: Center(child: CircularProgressIndicator()),
              ),
          };
        },
      ),
    );
  }

  Widget _buildGroupsDrawer(S5Messenger s5messenger) {
    return BlocProvider(
      create: (context) => GroupsCubit(s5messenger: s5messenger),
      child: GroupsDrawer(
        s5messenger: s5messenger,
      ),
    );
  }
}

class GroupsDrawer extends StatelessWidget {
  final S5Messenger s5messenger;
  const GroupsDrawer({super.key, required this.s5messenger});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            child: Text('Groups'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: () => context.read<GroupsCubit>().createGroup(),
              child: const Text('Create Group'),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          Expanded(
            child: BlocBuilder<GroupsCubit, GroupsState>(
              builder: (context, state) {
                if (state is GroupsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is GroupsError) {
                  return Center(child: Text(state.message));
                }
                if (state is GroupsLoaded) {
                  return GroupListView(
                    groups: state.groups,
                    s5messenger: s5messenger,
                  );
                }
                return const SizedBox(); // Initial state
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GroupListView extends StatelessWidget {
  final List<dynamic> groups;
  final S5Messenger s5messenger;

  const GroupListView(
      {super.key, required this.groups, required this.s5messenger});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return ListTile(
          onTap: () {
            context.read()<GroupsCubit>().selectGroup(group['id']);
            Navigator.pop(context); // Close drawer
          },
          onLongPress: () async {
            final res = await showTextInputDialog(
              context: context,
              textFields: [
                DialogTextField(hintText: 'Edit Group Name (local)'),
              ],
            );
            if (res != null && res.isNotEmpty) {
              context.read<GroupsCubit>().renameGroup(group['id'], res.first);
            }
          },
          title: Text(group['name']),
          subtitle: Text(group['id']),
          selected: s5messenger.messengerState.groupId == group['id'],
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
        );
      },
    );
  }
}
