import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/init_router/init_router_cubit.dart';
import 'package:luogo/cubit/init_router/init_router_state.dart';
import 'package:luogo/view/page/home.dart';
import 'package:luogo/view/page/login.dart';

class InitRouterPage extends StatelessWidget {
  const InitRouterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => InitRouterCubit()..checkPreferences(),
      child: BlocListener<InitRouterCubit, InitRouterState>(
        listener: (context, state) {
          if (state is InitRouterSuccess) {
            _navigateBasedOnRoute(context, state.route);
          }
        },
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Text("Routing..."), CircularProgressIndicator()],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateBasedOnRoute(BuildContext context, RouteType route) {
    final page = route == RouteType.home ? const HomePage() : const LoginPage();
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (context) => page), (route) => false);
  }
}
