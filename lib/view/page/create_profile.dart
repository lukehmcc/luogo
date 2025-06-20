import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:luogo/cubit/create_profile/create_profile_cubit.dart';
import 'package:luogo/cubit/create_profile/create_profile_state.dart';
import 'package:luogo/view/page/home.dart';

class CreateProfilePage extends StatelessWidget {
  const CreateProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
        create: (context) => CreateProfilePageCubit(),
        // Put a blocListener here to handle incoming messages
        child: BlocListener<CreateProfilePageCubit, CreateProfilePageState>(
          listener: (context, state) {
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
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage()),
                  (route) => false);
            }
          },
          // Then actually build the app here
          child: Scaffold(
            appBar: AppBar(title: const Text('Create Profile')),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BlocBuilder<CreateProfilePageCubit, CreateProfilePageState>(
                    builder: (context, state) {
                      final cubit = context.read<CreateProfilePageCubit>();
                      return Column(
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
                                      cubit.nameController.text[0]
                                          .toUpperCase(),
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
                              IconButton(
                                icon: const Icon(
                                    Icons.colorize), // Eye dropper style icon
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
                                tooltip: 'Pick a color',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                              onPressed: cubit.savePreferences,
                              child: Text("Let's go!")),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
