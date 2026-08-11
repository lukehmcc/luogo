import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/ask_for_location/ask_for_location_cubit.dart';
import 'package:luogo/view/page/init_router.dart';
import 'package:luogo/view/widgets/permission_tile.dart';

class AskForLocationPermissionPage extends StatelessWidget {
  const AskForLocationPermissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return BlocListener<AskForLocationCubit, AskForLocationState>(
      listener: (BuildContext context, AskForLocationState state) {
        if (state is AskForLocationApproved) {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const InitRouterPage(),
            ),
          );
        }
      },
      child: Scaffold(
        body: BlocBuilder<AskForLocationCubit, AskForLocationState>(
          builder: (context, state) {
            if (state is! AskForLocationInitial) {
              return const SizedBox.shrink();
            }
            final AskForLocationCubit cubit =
                BlocProvider.of<AskForLocationCubit>(context);

            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Illustration
                      SizedBox(
                        height: 300,
                        child: Image.asset(
                          "assets/fake-map.png",
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title
                      Text(
                        "Luogo Needs Permission",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Location access prompt
                      PermissionTile(
                        title: "Location access",
                        subtitle: "Luogo shares your location with "
                            "your group members.",
                        granted: state.locationGranted,
                        checking: state.checking,
                        onRequest: cubit.requestLocation,
                      ),

                      // Reduced battery optimization prompt (recommended)
                      PermissionTile(
                        title: "Reduced battery optimization",
                        subtitle:
                            "Optimized mode delays delivery. Disable for better reliability.",
                        granted: state.batteryExempt,
                        checking: state.checking,
                        onRequest: cubit.requestBattery,
                      ),

                      const SizedBox(height: 10),

                      // Continue
                      Padding(
                        padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (state.locationGranted && !state.checking)
                                    ? cubit.continueToApp
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Continue"),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
