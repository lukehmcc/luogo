import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/nerd_stats/nerd_stats_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Compute the persisted sync-history stats for the Nerd Stats page.
///
/// Reads prefs synchronously (the values are cached at construction time), so
/// the initial state is emitted immediately with no loading phase.
class NerdStatsCubit extends Cubit<NerdStatsState> {
  NerdStatsCubit({required this.prefs}) : super(NerdStatsState.compute(prefs));

  final SharedPreferencesWithCache prefs;

  /// Re-reads the sync history from prefs. Safe to call after new syncs have
  /// been recorded while the page was open.
  void refresh() {
    if (!isClosed) emit(NerdStatsState.compute(prefs));
  }
}
