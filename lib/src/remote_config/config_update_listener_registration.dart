class ConfigUpdateListenerRegistration {
  ConfigUpdateListenerRegistration(this._onRemove);

  final void Function() _onRemove;

  void remove() => _onRemove();
}
