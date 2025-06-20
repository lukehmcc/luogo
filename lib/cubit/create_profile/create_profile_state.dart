abstract class CreateProfilePageState {}

class CreateProfileInitial extends CreateProfilePageState {}

class CreateProfileTextEdited extends CreateProfilePageState {}

class CreateProfileColorChanged extends CreateProfilePageState {}

class CreateProfileSuccess extends CreateProfilePageState {}

class CreateProfileError extends CreateProfilePageState {
  final String message;
  CreateProfileError(this.message);
}
