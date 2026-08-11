/// Base for all settings states. Carries the background/battery status fields
/// so every emitted state reflects the full picture, regardless of which
/// relay-probe stage is current.
sealed class SettingsState {
  const SettingsState({
    this.batteryExempt = false,
    this.backgroundFetchStatus = -1,
    this.lastBackgroundSync,
    this.checkingBackground = false,
  });

  /// Whether Android battery optimization is disabled for the app.
  final bool batteryExempt;

  /// `BackgroundFetch.status` value; -1 means unknown/not yet read.
  final int backgroundFetchStatus;

  /// ISO timestamp of the last successful background sync, if any.
  final String? lastBackgroundSync;

  /// True while the OS task status is being (re)read.
  final bool checkingBackground;
}

class SettingsInitial extends SettingsState {
  const SettingsInitial({
    super.batteryExempt,
    super.backgroundFetchStatus,
    super.lastBackgroundSync,
    super.checkingBackground,
  });
}

/// A reachability probe of the entered relay URL is in flight.
class SettingsServerChecking extends SettingsState {
  const SettingsServerChecking({
    super.batteryExempt,
    super.backgroundFetchStatus,
    super.lastBackgroundSync,
    super.checkingBackground,
  });
}

/// The entered URL answered a health check; it has been saved as the active
/// relay and the live client rebinds to it.
class SettingsServerOnline extends SettingsState {
  const SettingsServerOnline({
    super.batteryExempt,
    super.backgroundFetchStatus,
    super.lastBackgroundSync,
    super.checkingBackground,
  });
}

/// Nothing reachable answered at the entered URL.
class SettingsServerOffline extends SettingsState {
  const SettingsServerOffline({
    super.batteryExempt,
    super.backgroundFetchStatus,
    super.lastBackgroundSync,
    super.checkingBackground,
  });
}

/// The entered URL answered a health check but speaks a different wire
/// protocol version than this app. The URL is not saved.
class SettingsServerVersionMismatch extends SettingsState {
  final int serverVersion;
  SettingsServerVersionMismatch({
    required this.serverVersion,
    super.batteryExempt,
    super.backgroundFetchStatus,
    super.lastBackgroundSync,
    super.checkingBackground,
  });
}