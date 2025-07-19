import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/home_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';

class HomeCubit extends Cubit<HomeState> {
  GroupInfo? group;
  HomeCubit() : super(HomeInitial());

  void groupSelected(GroupInfo groupSelected) {
    group = groupSelected;
    if (group != null) {
      emit(HomeGroupSelected(group!));
    } else {
      logger.e("Group doesn't exist");
    }
  }

  void clearSelection() {
    emit(HomeInitial());
  }
}
