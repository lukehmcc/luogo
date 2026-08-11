sealed class ServerSelectState {}

/// The dialog just opened; the first probe is about to run.
class ServerSelectInitial extends ServerSelectState {}

/// A reachability probe of the candidate relay URL is in flight.
class ServerSelectChecking extends ServerSelectState {}

/// The candidate URL answered a health check with a compatible protocol
/// version and may be used as this profile's relay.
class ServerSelectOnline extends ServerSelectState {}

/// Nothing reachable answered at the candidate URL.
class ServerSelectOffline extends ServerSelectState {}

/// The candidate URL answered but speaks a different wire protocol version
/// than this app. The server cannot be used.
class ServerSelectVersionMismatch extends ServerSelectState {
  final int serverVersion;
  ServerSelectVersionMismatch({required this.serverVersion});
}