import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/login/login_state.dart';
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

// Cubit for state management
class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(LoginInitial()) {
    selectedColor = getRandomLightColor();
    nameController.addListener(() {
      emit(LoginTextEdited());
    });
  }

  final TextEditingController nameController = TextEditingController();
  Color? selectedColor;

  void selectColor(Color color) {
    selectedColor = color;
    emit(LoginColorSelected(color));
  }

  Future<void> savePreferences(BuildContext context) async {
    if (nameController.text.isEmpty || selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both name and color')),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', nameController.text);
      await prefs.setInt('userColor', selectedColor?.toARGB32() ?? 0);
      emit(LoginSuccess());
    } catch (e) {
      emit(LoginError(e.toString()));
    }
  }
}
