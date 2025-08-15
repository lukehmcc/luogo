import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/groups_drawer/groups_drawer_cubit.dart';
import 'package:luogo/cubit/home/groups_drawer/groups_drawer_state.dart';
import 'package:luogo/cubit/home/home_cubit.dart';
import 'package:luogo/cubit/home/settings/settings_cubit.dart';
import 'package:luogo/model/group_info.dart';
import 'package:luogo/view/page/home/settings.dart';
import 'package:s5_messenger/s5_messenger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Drawer widget that displays and manages a list of chat groups.
class GroupsDrawer extends StatelessWidget {
  final S5Messenger s5messenger;
  final SharedPreferencesWithCache prefs;
  const GroupsDrawer({
    super.key,
    required this.s5messenger,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton(
                onPressed: context.read<GroupsDrawerCubit>().createGroup,
                heroTag: "group-drawer-floater",
                child: const Icon(Icons.add),
              ),
            ),
            Column(
              children: [
                const ListTile(
                  title: Text(
                    'Groups',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                Expanded(
                  child: BlocBuilder<GroupsDrawerCubit, GroupsDrawerState>(
                    builder: (context, state) {
                      if (state is GroupsDrawerLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is GroupsDrawerError) {
                        return Center(child: Text(state.message));
                      }
                      if (state is GroupsDrawerLoaded) {
                        return GroupListView(
                          groups: state.groups,
                          s5messenger: s5messenger,
                        );
                      }
                      return const SizedBox(); // Initial state
                    },
                  ),
                ),
                // Add this bottom bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        // Navigate to settings page
                        Navigator.push<Widget>(
                          context,
                          MaterialPageRoute<Widget>(
                            builder: (BuildContext context) => BlocProvider(
                              create: (BuildContext context) =>
                                  SettingsCubit(prefs: prefs),
                              child: const SettingsPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GroupListView extends StatelessWidget {
  final GroupInfoList groups;
  final S5Messenger s5messenger;

  const GroupListView(
      {super.key, required this.groups, required this.s5messenger});

  @override
  Widget build(BuildContext context) {
    // Put streambuilder here so each time the chat state updates it can update it
    return StreamBuilder<void>(
        stream: s5messenger.messengerState.stream,
        builder: (context, snapshot) {
          if (groups.length == 0) {
            return Center(
              child: Text("Create a group with the + button!"),
            );
          }
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                onTap: () {
                  context
                      .read<GroupsDrawerCubit>()
                      .selectGroup(group.id); // Update backend
                  context.read<HomeCubit>().groupSelected(group); // Update UI
                  Navigator.pop(context); // Close drawer
                },
                onLongPress: () async {
                  final res = await showTextInputDialog(
                    context: context,
                    textFields: [
                      DialogTextField(hintText: 'Edit Group Name (local)'),
                    ],
                  );
                  if (res != null && res.isNotEmpty && context.mounted) {
                    context
                        .read<GroupsDrawerCubit>()
                        .renameGroup(group.id, res.first);
                  }
                },
                title: Text(group.name),
                subtitle: Text(context
                        .read<GroupsDrawerCubit>()
                        .getMemebersFromGroup(group.id) ??
                    "Members: you"),
                selected: s5messenger.messengerState.groupId == group.id,
                selectedTileColor:
                    Theme.of(context).colorScheme.primaryContainer,
              );
            },
          );
        });
  }
}
