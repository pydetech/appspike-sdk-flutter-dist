class RemoteConfigSettings {
  RemoteConfigSettings({
    required this.fetchTimeout,
    required this.minimumFetchInterval,
  }) {
    if (minimumFetchInterval.isNegative) {
      throw ArgumentError.value(
        minimumFetchInterval,
        'minimumFetchInterval',
        'must be non-negative',
      );
    }
    if (fetchTimeout <= Duration.zero) {
      throw ArgumentError.value(
        fetchTimeout,
        'fetchTimeout',
        'must be greater than zero',
      );
    }
  }

  RemoteConfigSettings.defaults()
    : this(
        fetchTimeout: const Duration(seconds: 60),
        minimumFetchInterval: const Duration(hours: 12),
      );

  final Duration fetchTimeout;

  final Duration minimumFetchInterval;
}
