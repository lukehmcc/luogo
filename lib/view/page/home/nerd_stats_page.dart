import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/nerd_stats/nerd_stats_cubit.dart';
import 'package:luogo/cubit/home/nerd_stats/nerd_stats_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Diagnostics page showing recent relay-sync intervals and averages, broken
/// down by trigger source (periodic vs significant change).
class NerdStatsPage extends StatelessWidget {
  const NerdStatsPage({super.key, required this.prefs});

  final SharedPreferencesWithCache prefs;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NerdStatsCubit(prefs: prefs),
      child: BlocBuilder<NerdStatsCubit, NerdStatsState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Nerd Stats'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => context.read<NerdStatsCubit>().refresh(),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            body: SafeArea(
              child: state.hasData
                  ? _StatsView(state: state)
                  : const _EmptyView(),
            ),
          );
        },
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView({required this.state});
  final NerdStatsState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Averages'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.av_timer),
                title: const Text('Overall average'),
                subtitle: Text(state.averageInterval == null
                    ? 'n/a'
                    : NerdStatsState.formatDuration(state.averageInterval!)),
                trailing: Text('${state.intervalCount} intervals'),
              ),
              const Divider(height: 1),
              ...state.bySource.entries.map((e) => ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text('${e.key} average'),
                    subtitle:
                        Text(NerdStatsState.formatDuration(e.value.average)),
                    trailing: Text('${e.value.count}'),
                  )),
            ],
          ),
        ),
        _sectionTitle('Recent intervals'),
        Card(
          child: Column(
            children: state.recent.map((it) => ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(NerdStatsState.formatDuration(it.interval)),
              subtitle: Text('${it.source} · ${_fmtTime(it.at)}'),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(text,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No syncs recorded yet.\n\n'
            'Syncs happen during background fetch or '
            'iOS significant-location changes.\n\n'
            'Once more syncs accumulate, this page will show '
            'intervals and averages here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
}
