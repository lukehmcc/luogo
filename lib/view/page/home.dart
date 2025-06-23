import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/home_cubit.dart';
import 'package:luogo/cubit/home/home_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/view/page/map.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GroupsCubit(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
        ),
        drawer: const GroupsDrawer(),
        extendBodyBehindAppBar: true,
        body: MapView(),
      ),
    );
  }
}

class GroupsDrawer extends StatelessWidget {
  const GroupsDrawer({super.key});

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
                  return GroupListView(groups: state.groups);
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

  const GroupListView({super.key, required this.groups});

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
