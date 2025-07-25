import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:luogo/cubit/create_profile/create_profile_cubit.dart';
import 'package:luogo/cubit/create_profile/create_profile_state.dart';
import 'package:luogo/cubit/map/map_cubit.dart';
import 'package:luogo/services/location_service.dart';
import 'package:luogo/view/page/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateProfilePage extends StatelessWidget {
  final SharedPreferencesWithCache prefs;
  final LocationService locationService;
  const CreateProfilePage({
    super.key,
    required this.prefs,
    required this.locationService,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CreateProfilePageCubit>(
        create: (BuildContext context) => CreateProfilePageCubit(prefs: prefs),
        // Put a blocListener here to handle incoming messages
        child: BlocListener<CreateProfilePageCubit, CreateProfilePageState>(
          listener: (BuildContext context, CreateProfilePageState state) {
            // If the login is not sucsessful, let the user know
            if (state is CreateProfileError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  duration: Duration(seconds: 3), // Optional: Adjust duration
                ),
              );
            }
            // If it is sucsessful, then push them through to the homepage
            if (state is CreateProfileSuccess) {
              Navigator.pushAndRemoveUntil<dynamic>(
                  context,
                  MaterialPageRoute<dynamic>(
                      builder: (BuildContext context) => BlocProvider<MapCubit>(
                          create: (context) => MapCubit(
                                locationService: locationService,
                                prefs: prefs,
                              ),
                          child: HomePage(
                            prefs: prefs,
                            locationService: locationService,
                          ))),
                  (Route<dynamic> route) => false);
            }
          },
          // Then actually build the app here
          child: Scaffold(
            appBar: AppBar(title: const Text('Create Profile')),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child:
                  BlocBuilder<CreateProfilePageCubit, CreateProfilePageState>(
                builder: (BuildContext context, CreateProfilePageState state) {
                  final CreateProfilePageCubit cubit =
                      context.read<CreateProfilePageCubit>();
                  return Center(
                      child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 200, // Diameter of the circle
                              height: 200,
                              decoration: BoxDecoration(
                                color: cubit.selectedColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (cubit.nameController.text.isNotEmpty)
                              Positioned.fill(
                                child: Center(
                                  child: Text(
                                    cubit.nameController.text[0].toUpperCase(),
                                    style: TextStyle(
                                      // Optional: Adjust font size/weight for visibility
                                      fontSize: 100,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        Column(
                          children: [
                            if (cubit.nameController.text.isNotEmpty) ...[
                              Text(
                                cubit.nameController.text,
                                style: TextStyle(fontSize: 20),
                              ),
                              const SizedBox(height: 20),
                            ],
                            // Other widgets...
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: cubit.nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Enter your name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: cubit.selectedColor,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(
                                  2), // Adjust padding as needed
                              child: IconButton(
                                icon: const Icon(
                                  Icons.colorize,
                                  color: Colors
                                      .white, // Ensure icon is visible against the background
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text(
                                            "Pick your profile color!"),
                                        content: SingleChildScrollView(
                                          child: BlockPicker(
                                            pickerColor: cubit.pickerColor,
                                            onColorChanged: cubit.onColorPicked,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                            onPressed: cubit.savePreferences,
                            child: Text("Let's go!")),
                      ],
                    ),
                  ));
                },
              ),
            ),
          ),
        ));
  }
}
