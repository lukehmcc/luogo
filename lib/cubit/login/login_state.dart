import 'package:flutter/material.dart';

abstract class LoginState {}

class LoginInitial extends LoginState {}

class LoginColorSelected extends LoginState {
  final Color color;
  LoginColorSelected(this.color);
}

class LoginTextEdited extends LoginState {}

class LoginSuccess extends LoginState {}

class LoginError extends LoginState {
  final String message;
  LoginError(this.message);
}
