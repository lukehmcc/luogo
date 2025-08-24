import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/ask_for_location/ask_for_location_cubit.dart';
import 'package:luogo/view/page/init_router.dart';

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
        } else if (state is AskForLocationDenied) {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const InitRouterPage(),
            ),
          );
        }
      },
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                  "Luogo Needs Your Location",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle / explanation
                Text(
                  "Luogo is a location sharing app, so without your location "
                  "it’s rather hard to do that. The app will still work, "
                  "but not ideally — be warned!",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          BlocProvider.of<AskForLocationCubit>(context)
                              .denyRequestPerms(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("No Thanks"),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () =>
                          BlocProvider.of<AskForLocationCubit>(context)
                              .requestPerms(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme
                            .colorScheme.primary, // filled with primary color
                        foregroundColor: theme
                            .colorScheme.onPrimary, // makes text/icons readable
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Continue"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
