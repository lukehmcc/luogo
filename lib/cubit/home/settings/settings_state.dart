abstract class SettingsState {}

class SettingsInitial extends SettingsState {}

/// A reachability probe of the entered relay URL is in flight.
class SettingsServerChecking extends SettingsState {}

/// The entered URL answered a health check; it has been saved as the active
/// relay and the live client rebinds to it.
class SettingsServerOnline extends SettingsState {}

/// Nothing reachable answered at the entered URL.
class SettingsServerOffline extends SettingsState {}