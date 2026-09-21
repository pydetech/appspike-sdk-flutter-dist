enum RemoteConfigFetchStatus {
  noFetchYet('NO_FETCH_YET'),

  success('SUCCESS'),

  failure('FAILURE'),

  throttle('THROTTLED');

  const RemoteConfigFetchStatus(this.wireName);

  final String wireName;

  static RemoteConfigFetchStatus fromWireName(String? wireName) =>
      RemoteConfigFetchStatus.values.firstWhere(
        (status) => status.wireName == wireName,
        orElse: () => RemoteConfigFetchStatus.noFetchYet,
      );
}

enum ValueSource { valueStatic, valueDefault, valueRemote }
