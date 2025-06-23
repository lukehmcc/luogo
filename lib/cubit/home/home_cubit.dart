import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/home_state.dart';
import 'package:luogo/main.dart';

class GroupsCubit extends Cubit<GroupsState> {
  GroupsCubit() : super(GroupsInitial()) {
    loadGroups();
  }

  Future<void> loadGroups() async {
    emit(GroupsLoading());
    try {
      final groups = s5messenger.groupsBox.values.toList();
      emit(GroupsLoaded(groups));
    } catch (e) {
      emit(GroupsError(e.toString()));
    }
  }

  Future<void> createGroup() async {
    try {
      await s5messenger.createNewGroup();
      loadGroups(); // Refresh the list
    } catch (e) {
      emit(GroupsError(e.toString()));
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
      emit(GroupsError(e.toString()));
    }
  }
}
