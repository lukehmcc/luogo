import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/groups_drawer/groups_drawer_cubit.dart';
import 'package:luogo/cubit/home/groups_drawer/groups_drawer_state.dart';
import 'package:luogo/cubit/home/home_cubit.dart';
import 'package:luogo/cubit/home/settings/settings_cubit.dart';
import 'package:luogo/main.dart';
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
                // When creating new group get the name you want first
                onPressed: () async {
                  final res = await showTextInputDialog(
                    context: context,
                    style: AdaptiveStyle
                        .material, // cupertino has coloring issues so force material
                    textFields: [
                      DialogTextField(hintText: 'New Group Name:'),
                    ],
                  );
                  if (res != null && res.isNotEmpty && context.mounted) {
                    logger.d("the new group name is ${res.first}");
                    await context
                        .read<GroupsDrawerCubit>()
                        .createGroup(res.first);
                  } else if (context.mounted) {
                    logger.d("the new group name is null");
                    await context.read<GroupsDrawerCubit>().createGroup(null);
                  }
                },
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
            itemBuilder: (BuildContext context, int index) {
              final GroupInfo group = groups[index];
              if (s5messenger.groupsBox.get(group.id) == null) {
                return Container();
              }
              return ListTile(
                onTap: () {
                  context
                      .read<GroupsDrawerCubit>()
                      .selectGroup(group.id); // Update backend
                  context.read<HomeCubit>().groupSelected(group); // Update UI
                  Navigator.pop(context); // Close drawer
                },
                title: Text(group.name),
                subtitle: Text(context
                        .read<GroupsDrawerCubit>()
                        .getMemebersFromGroup(group.id) ??
                    "Members: you"),
                selected: s5messenger.messengerState.groupId == group.id,
                selectedTileColor:
                    Theme.of(context).colorScheme.primaryContainer,
                trailing: PopupMenuButton<String>(
                  onSelected: (String value) async {
                    // Handle menu item selection
                    switch (value) {
                      case 'leave':
                        // First deselect the group if selected
                        final GroupInfo? currentlySelected =
                            context.read<HomeCubit>().group;
                        if (currentlySelected != null &&
                            currentlySelected.id == group.id) {
                          context
                              .read<GroupsDrawerCubit>()
                              .selectGroup(null); // Update backend
                          context
                              .read<HomeCubit>()
                              .groupSelected(null); // Update UI
                        }

                        // Then Leave
                        context.read<GroupsDrawerCubit>().leaveGroup(group.id);
                      case 'rename':
                        final res = await showTextInputDialog(
                          context: context,
                          style: AdaptiveStyle
                              .material, // cupertino has coloring issues so force material
                          textFields: [
                            DialogTextField(
                              hintText: 'Edit Group Name (local)',
                            ),
                          ],
                        );
                        if (res != null && res.isNotEmpty && context.mounted) {
                          // on rename both rename the group, then reselect it so the update propagates
                          context
                              .read<GroupsDrawerCubit>()
                              .renameGroup(group.id, res.first);
                          logger.d(group);
                          context.read<HomeCubit>().groupSelected(GroupInfo(
                              id: group.id, name: res.first)); // Update UI
                        }
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          Center(
                            child: Text('Rename'),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'leave',
                      child: Row(
                        children: [
                          Icon(Icons.delete),
                          Center(
                            child: Text('Leave'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  icon: Icon(Icons.more_vert), // Icon to trigger the menu
                ),
              );
            },
          );
        });
  }
}
