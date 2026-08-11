part of 'ask_for_location_cubit.dart';

sealed class AskForLocationState {
  const AskForLocationState();
}

/// The permission screen is active. [checking] is true while statuses are
/// being read; [locationGranted]/[batteryExempt] reflect the actual platform
/// state.
class AskForLocationInitial extends AskForLocationState {
  const AskForLocationInitial({
    required this.locationGranted,
    required this.batteryExempt,
    this.checking = false,
  });

  final bool locationGranted;
  final bool batteryExempt;
  final bool checking;
}

/// Everything required is allowed and the app can move on.
class AskForLocationApproved extends AskForLocationState {}