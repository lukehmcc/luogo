abstract class GroupsDrawerState {}

class GroupsDrawerInitial extends GroupsDrawerState {}

class GroupsDrawerLoading extends GroupsDrawerState {}

class GroupsDrawerLoaded extends GroupsDrawerState {
  final List<dynamic> groups;
  GroupsDrawerLoaded(this.groups);
}

class GroupsDrawerError extends GroupsDrawerState {
  final String message;
  GroupsDrawerError(this.message);
}
