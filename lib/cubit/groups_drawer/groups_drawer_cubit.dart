import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/groups_drawer/groups_drawer_state.dart';
import 'package:s5_messenger/s5_messenger.dart';

class GroupsDrawerCubit extends Cubit<GroupsDrawerState> {
  S5Messenger? s5messenger; // mutable so can load async

  GroupsDrawerCubit() : super(GroupsDrawerInitial());

  Future<void> setS5Messenger(S5Messenger s5messengerIn) async {
    s5messenger = s5messengerIn;
    emit(GroupsDrawerLoading());
    loadGroups();
  }

  Future<void> loadGroups() async {
    if (s5messenger == null) return;
    emit(GroupsDrawerLoading());
    try {
      final groups = s5messenger!.groupsBox.values.toList();
      final currentGroupId = s5messenger!.messengerState.groupId;
      emit(GroupsDrawerLoaded(groups, currentGroupId));
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
    }
  }

  Future<void> createGroup() async {
    if (s5messenger == null) return;
    try {
      await s5messenger!.createNewGroup();
      loadGroups(); // Refresh the list
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
    }
  }

  Future<void> selectGroup(String groupId) async {
    if (s5messenger == null) return;
    try {
      s5messenger!.messengerState.groupId = groupId;
      s5messenger!.messengerState.update();
      final groups = s5messenger!.groupsBox.values.toList();
      emit(GroupsDrawerLoaded(groups, groupId)); // Use same state
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
    }
  }

  Future<void> renameGroup(String groupId, String newName) async {
    if (s5messenger == null) return;
    try {
      s5messenger!.group(groupId).rename(newName);
      loadGroups(); // Refresh the list
    } catch (e) {
      emit(GroupsDrawerError(e.toString()));
    }
  }
}
