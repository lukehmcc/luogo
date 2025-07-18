import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/groups_drawer/groups_drawer_cubit.dart';
import 'package:luogo/cubit/home/groups_drawer/groups_drawer_state.dart';
import 'package:luogo/cubit/home/home_cubit.dart';
import 'package:luogo/model/group_info.dart';
import 'package:s5_messenger/s5_messenger.dart';

class GroupsDrawer extends StatelessWidget {
  final S5Messenger s5messenger;
  const GroupsDrawer({super.key, required this.s5messenger});

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: () {
                context.read<GroupsDrawerCubit>().createGroup();
              },
              child: const Text('Create Group'),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
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
                  // if a group is selected, make sure to set the homestate
                  if (state.group != null) {
                    final homeCubit = BlocProvider.of<HomeCubit>(context);
                    homeCubit.groupSelected(state.group!);
                  }
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
    ));
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
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                onTap: () {
                  context.read<GroupsDrawerCubit>().selectGroup(group.id);
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
                subtitle: Text(group.id),
                selected: s5messenger.messengerState.groupId == group.id,
                selectedTileColor:
                    Theme.of(context).colorScheme.primaryContainer,
              );
            },
          );
        });
  }
}
