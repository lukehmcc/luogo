import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/settings/settings_state.dart';
import 'package:luogo/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Cubit class for managing the settings state.
///
/// Example usage:
/// ```dart
/// BlocProvider(
///   create: (context) =>; SettinsgCubit(),
///   child: YourSettingsWidget(),
/// )
/// ```

class SettingsCubit extends Cubit<SettingsState> {
  SharedPreferencesWithCache prefs;
  SettingsCubit({
    required this.prefs,
  }) : super(SettingsInitial()) {
    String? nodeString = prefs.getString('s5-node');
    if (nodeString != null) {
      controller.text = nodeString;
    }
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      String v = packageInfo.version;
      String b = packageInfo.buildNumber;
      version = "version $v+$b";
      emit(state);
    });
  }
  TextEditingController controller = TextEditingController();
  String version = "";

  void setS5Node() {
    if (_validateUrl(controller.text)) {
      logger.d("valid Url time");
      prefs.setString('s5-node', controller.text);
      emit(SettingsNewNodeSucsess());
    } else {
      logger.d("invald url");
      emit(SettingsNewNodeError());
    }
  }

  bool _validateUrl(String url) {
    if (url.isEmpty) return true; // Allow empty (if needed)
    final Uri? uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'wss');
  }
}
