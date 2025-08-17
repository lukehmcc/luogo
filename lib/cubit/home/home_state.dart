import 'package:luogo/model/group_info.dart';

abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeGroupSelected extends HomeState {
  final GroupInfo? group;
  HomeGroupSelected(this.group);
}
