part of 'ask_for_location_cubit.dart';

abstract class AskForLocationState {}

class AskForLocationInitial extends AskForLocationState {}

class AskForLocationDenied extends AskForLocationState {}

class AskForLocationApproved extends AskForLocationState {}
