import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/settings/settings_cubit.dart';
import 'package:luogo/cubit/home/settings/settings_state.dart';

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
                  // ElevatedButton(
                  //     onPressed: () async {
                  //       final Directory dir =
                  //           await getApplicationSupportDirectory();
                  //       final String logPath = p.join(dir.path, 'log.txt');
                  //       if (context.mounted) {
                  //         Navigator.of(context).push(
                  //           MaterialPageRoute(
                  //             builder: (_) => TextViewerPage(
                  //               textViewer: TextViewer.asset(
                  //                 logPath,
                  //                 ignoreCase: true,
                  //               ),
                  //               showSearchAppBar: true,
                  //             ),
                  //           ),
                  //         );
                  //       }
                  //     },
                  //     child: Text("Logs")),
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
