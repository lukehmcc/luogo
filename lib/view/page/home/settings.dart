import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/settings/settings_cubit.dart';
import 'package:luogo/cubit/home/settings/settings_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/utils/check_s5_connectivity.dart';
import 'package:luogo/view/widgets/file_viewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Class that defines settings page
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsCubit cubit = context.read<SettingsCubit>();
    return BlocListener<SettingsCubit, SettingsState>(
      listener: (BuildContext context, SettingsState state) {
        if (state is SettingsNewNodeError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Invalid URL')));
        }
      },
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const ListTile(
                    title: Text(
                      'Settings',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: cubit.controller,
                                    decoration: InputDecoration(
                                      labelText: 'S5 Node',
                                      border: OutlineInputBorder(),
                                      hintText: cubit.controller.text,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.save),
                                  onPressed: () {
                                    cubit.setS5Node();
                                  },
                                ),
                              ],
                            )),
                      ],
                    ),
                  ),
                  ElevatedButton(
                      onPressed: () async {
                        final Directory dir =
                            await getApplicationSupportDirectory();
                        final String logPath =
                            p.join(dir.path, 'log', 'latest.log');
                        logger.d("reading log from: $logPath");
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: const Text('Log Viewer')),
                                body: SafeArea(
                                  child: TextFileViewer(filePath: logPath),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text("Logs")),
                  Text(BlocProvider.of<SettingsCubit>(context).version),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
