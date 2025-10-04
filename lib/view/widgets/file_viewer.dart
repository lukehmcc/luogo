import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/widgets/file_viewer/file_viewer_cubit.dart';
import 'package:luogo/cubit/widgets/file_viewer/file_viewer_state.dart';
import 'package:luogo/view/widgets/silly_progress_indicator.dart';

// A quick and simple file viewer for viewing logs
class TextFileViewer extends StatelessWidget {
  final String filePath;
  const TextFileViewer({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) => BlocProvider(
      create: (_) => FileViewerCubit(filePath),
      child: BlocBuilder<FileViewerCubit, FileViewerState>(
        builder: (_, state) => state.isLoading
            ? const Center(child: SillyCircularProgressIndicator())
            : Scrollbar(
                thickness: 10.0,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      state.content,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ),
      ));
}
