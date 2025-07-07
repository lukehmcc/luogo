import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luogo/cubit/map/key_pair_qr/keypair_qr_state.dart';

class KeypairQRCubit extends Cubit<KeypairQRState> {
  KeypairQRCubit() : super(KeypairQRInitial());

  bool isQRSelected = true;
  void setQRSelected(bool selected) {
    isQRSelected = selected;
    emit(KeypairQSelection(isQRSelected: isQRSelected));
  }
}
