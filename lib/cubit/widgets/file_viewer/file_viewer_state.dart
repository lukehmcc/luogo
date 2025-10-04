// STATE
class FileViewerState {
  final String content;
  final bool isLoading;
  const FileViewerState({this.content = '', this.isLoading = true});
  FileViewerState copyWith({String? content, bool? isLoading}) =>
      FileViewerState(
          content: content ?? this.content,
          isLoading: isLoading ?? this.isLoading);
}
