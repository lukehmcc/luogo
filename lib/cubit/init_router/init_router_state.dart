abstract class InitRouterState {}

class InitRouterInitial extends InitRouterState {}

class InitRouterLoading extends InitRouterState {}

class InitRouterSuccess extends InitRouterState {
  final RouteType route;
  InitRouterSuccess({required this.route});
}

enum RouteType { home, login, locationPerms }
