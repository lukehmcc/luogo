import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/groups_drawer/groups_drawer_state.dart';
import 'package:s5_messenger/s5_messenger.dart';

class GroupsDrawerCubit extends Cubit<GroupsDrawerState> {
  final S5Messenger s5messenger;

  GroupsDrawerCubit({required this.s5messenger})
      : super(GroupsDrawerInitial()) {
    loadGroups();
  }

  Future<void> loadGroups() async {
    emit(GroupsDrawerLoading());
    try {
      final groups = s5messenger.groupsBox.values.toList();
      emit(GroupsDrawerLoaded(groups));
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
    }
  }

  Future<void> createGroup() async {
    try {
      await s5messenger.createNewGroup();
      loadGroups(); // Refresh the list
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
    }
  }

  Future<void> selectGroup(String groupId) async {
    s5messenger.messengerState.groupId = groupId;
    s5messenger.messengerState.update();
    loadGroups(); // Refresh to update selected state
  }

  Future<void> renameGroup(String groupId, String newName) async {
    try {
      s5messenger.group(groupId).rename(newName);
      loadGroups(); // Refresh the list
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
    }
  }
}
