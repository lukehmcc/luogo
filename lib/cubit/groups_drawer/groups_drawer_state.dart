import 'package:luogo/model/group_info.dart';

abstract class GroupsDrawerState {}

class GroupsDrawerInitial extends GroupsDrawerState {}

class GroupsDrawerLoading extends GroupsDrawerState {}

class GroupsDrawerLoaded extends GroupsDrawerState {
  final GroupInfoList groups;
  final GroupInfo? group;
  GroupsDrawerLoaded(this.groups, [this.group]);
}

class GroupsDrawerError extends GroupsDrawerState {
  final String message;
  GroupsDrawerError(this.message);
}
