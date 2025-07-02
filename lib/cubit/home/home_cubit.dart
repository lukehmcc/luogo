import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/home/home_state.dart';
import 'package:luogo/main.dart';
import 'package:luogo/model/group_info.dart';

class HomeCubit extends Cubit<HomeState> {
  GroupInfo? group;
  HomeCubit() : super(HomeInitial());

  void groupSelected(GroupInfo groupSelected) {
    group = groupSelected;
    logger.d("New Group: $group");
    emit(HomeGroupSelected(group));
  }

  void clearSelection() {
    emit(HomeInitial());
  }
}
