import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/create_profile/create_profile_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Generates a random color so if the user doesn't pick it isn't always the same
Color getRandomLightColor() {
  final random = Random();
  final channels = [
    100 + random.nextInt(56),
    100 + random.nextInt(56),
    100 + random.nextInt(56)
  ];

  // Select one channel to boost
  final biasedChannel = random.nextInt(3);
  channels[biasedChannel] =
      200 + random.nextInt(56); // 200-255 for the biased channel

  return Color.fromRGBO(channels[0], channels[1], channels[2], 1.0);
}

/// A Cubit class for managing the state of a profile creation page.
///
/// This class handles:
/// - Managing the user's selected profile name through [nameController]
/// - Managing the user's selected profile color through [selectedColor] and [pickerColor]
/// - Generating a random light color for the initial profile color
/// - Validating and saving the profile data to SharedPreferences
///
/// The cubit emits different states based on user interactions:
/// - [CreateProfileInitial]: Initial state when the cubit is created
/// - [CreateProfileTextEdited]: When the user edits the name text field
/// - [CreateProfileColorChanged]: When the user selects a new color
/// - [CreateProfileSuccess]: When the profile is successfully saved
/// - [CreateProfileError]: When there's an error during profile saving
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) => CreateProfilePageCubit(prefs: prefs),
///   child: CreateProfilePage(),
/// )
/// ```
class CreateProfilePageCubit extends Cubit<CreateProfilePageState> {
  final SharedPreferencesWithCache prefs;

  CreateProfilePageCubit({required this.prefs})
      : super(CreateProfileInitial()) {
    selectedColor = getRandomLightColor();
    pickerColor = selectedColor;
    nameController.addListener(() {
      emit(CreateProfileTextEdited());
    });
  }

  final TextEditingController nameController = TextEditingController();
  Color? selectedColor;
  Color? pickerColor;

  // Callback for when color is updated from the picker
  void onColorPicked(Color color) {
    selectedColor = color;
    emit(CreateProfileColorChanged());
  }

  // If everything is okay, save the settings to prefs so you can move on
  Future<void> savePreferences() async {
    if (nameController.text.isEmpty || selectedColor == null) {
      emit(CreateProfileError('Please enter both name and color'));
      return;
    }

    try {
      await prefs.setString('name', nameController.text);
      await prefs.setInt('color', selectedColor?.toARGB32() ?? 0);
      emit(CreateProfileSuccess());
    } catch (e) {
      emit(CreateProfileError(e.toString()));
    }
  }
}
