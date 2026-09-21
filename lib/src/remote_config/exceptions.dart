class RemoteConfigFetchException implements Exception {
  const RemoteConfigFetchException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'RemoteConfigFetchException: $message';
}

class RemoteConfigThrottledException extends RemoteConfigFetchException {
  const RemoteConfigThrottledException(super.message, {this.throttleEndTime});

  final DateTime? throttleEndTime;

  @override
  String toString() => 'RemoteConfigThrottledException: $message';
}
