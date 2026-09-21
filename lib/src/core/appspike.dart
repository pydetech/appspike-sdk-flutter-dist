import '../remote_config/internal/remote_config_platform.dart';
import 'appspike_module.dart';

final class AppSpike {
  AppSpike._();

  static final AppSpike instance = AppSpike._();

  bool _initialized = false;

  Future<InitResult> initialize({
    required String apiKey,
    List<AppSpikeModule> modules = const <AppSpikeModule>[],
  }) async {
    if (_initialized) {
      return const InitResultSuccess();
    }
    final result = await RemoteConfigPlatform.instance.initialize(
      apiKey: apiKey,
    );
    if (!result.success) {
      return InitResultError(result.message ?? 'Failed to initialize');
    }
    _initialized = true;
    for (final module in modules) {
      await module.onSessionReady();
    }
    return const InitResultSuccess();
  }
}
