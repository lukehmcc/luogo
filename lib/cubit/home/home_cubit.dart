import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/home_state.dart';
import 'package:luogo/main.dart';

class HomeCubit extends Cubit<HomeState> {
  dynamic group;
  HomeCubit() : super(HomeInitial());

  void groupSelected(dynamic groupSelected) {
    group = groupSelected;
    logger.d("New Group: $group");
    emit(HomeGroupSelected(group));
  }

  void clearSelection() {
    emit(HomeInitial());
  }
}
