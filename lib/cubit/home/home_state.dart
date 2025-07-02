abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeGroupSelected extends HomeState {
  final dynamic group;
  HomeGroupSelected(this.group);
}
