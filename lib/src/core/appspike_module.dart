// ignore: one_member_abstracts
abstract interface class AppSpikeModule {
  Future<void> onSessionReady();
}

sealed class InitResult {
  const InitResult();
}

final class InitResultSuccess extends InitResult {
  const InitResultSuccess();
}

final class InitResultError extends InitResult {
  const InitResultError(this.message);

  final String message;
}
