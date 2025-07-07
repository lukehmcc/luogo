abstract class KeypairQRState {}

class KeypairQRInitial extends KeypairQRState {}

class KeypairQSelection extends KeypairQRState {
  final bool isQRSelected;
  KeypairQSelection({required this.isQRSelected});
}
