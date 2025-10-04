import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/widgets/file_viewer/file_viewer_state.dart';

class FileViewerCubit extends Cubit<FileViewerState> {
  final String filePath;
  FileViewerCubit(this.filePath) : super(const FileViewerState()) {
    loadFile();
  }
  Future<void> loadFile() async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      emit(state.copyWith(content: content, isLoading: false));
    } catch (e) {
      emit(state.copyWith(content: 'Error: $e', isLoading: false));
    }
  }
}
