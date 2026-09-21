import AppSpikeSDKCore
import AppSpikeSDKRemoteConfig
import Flutter
import Foundation

public class AppspikeRemoteConfigPlugin: NSObject, FlutterPlugin {
    private let remoteConfig = AppSpikeRemoteConfig.shared
    private var updatesSink: FlutterEventSink?
    private var updateRegistration: ConfigUpdateListenerRegistration?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AppspikeRemoteConfigPlugin()
        let channel = FlutterMethodChannel(
            name: "dev.appspike/remote_config",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)

        let events = FlutterEventChannel(
            name: "dev.appspike/remote_config/updates",
            binaryMessenger: registrar.messenger()
        )
        events.setStreamHandler(instance)
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "initialize":
            initialize(arguments, result)
        case "ensureInitialized":
            // No explicit await hook is needed; onSessionReady has already
            // built the core by the time initialize's callback fired.
            result(self.stateMap())
        case "setDefaults":
            let defaults = arguments["defaults"] as? [String: Any] ?? [:]
            remoteConfig.setDefaults(defaults)
            result(self.stateMap())
        case "setConfigSettings":
            let timeout = doubleValue(arguments["fetchTimeoutSeconds"]) ?? 60
            let interval =
                doubleValue(arguments["minimumFetchIntervalSeconds"]) ?? 43_200
            remoteConfig.configSettings = RemoteConfigSettings(
                minimumFetchInterval: interval,
                fetchTimeout: timeout
            )
            result(self.stateMap())
        case "setCustomSignals":
            setCustomSignals(arguments, result)
        case "fetch":
            fetch(arguments, result)
        case "activate":
            activate(result)
        case "fetchAndActivate":
            fetchAndActivate(result)
        case "getState":
            result(self.stateMap())
        case "reset":
            remoteConfig.reset()
            result(self.stateMap())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Method handlers

    private func initialize(
        _ arguments: [String: Any],
        _ result: @escaping FlutterResult
    ) {
        let apiKey = arguments["apiKey"] as? String ?? ""
        registerUpdateListener()
        AppSpike.shared.initialize(
            apiKey: apiKey,
            modules: [remoteConfig]
        ) { initResult in
            DispatchQueue.main.async {
                switch initResult {
                case .success:
                    result(["status": "success"])
                case .error(let message):
                    result(["status": "error", "message": message])
                }
            }
        }
    }

    private func setCustomSignals(
        _ arguments: [String: Any],
        _ result: @escaping FlutterResult
    ) {
        let signals = arguments["signals"] as? [String: Any] ?? [:]
        let builder = CustomSignals.Builder()
        for (key, value) in signals {
            builder.put(key: key, value: value is NSNull ? nil : "\(value)")
        }
        let customSignals = builder.build()
        Task {
            do {
                try await remoteConfig.setCustomSignals(customSignals)
                DispatchQueue.main.async { result(nil) }
            } catch {
                DispatchQueue.main.async {
                    result(self.fetchError(error))
                }
            }
        }
    }

    private func fetch(
        _ arguments: [String: Any],
        _ result: @escaping FlutterResult
    ) {
        let override = doubleValue(arguments["minimumFetchIntervalSeconds"])
        Task {
            do {
                if let override {
                    try await remoteConfig.fetch(
                        withExpirationDuration: override
                    )
                } else {
                    // Native 1.4.1 exposes a distinct no-argument `fetch()`
                    // that honors `configSettings.minimumFetchInterval`
                    // (Firebase parity), so the interval no longer has to be
                    // read out and passed back in.
                    try await remoteConfig.fetch()
                }
                DispatchQueue.main.async { result(self.stateMap()) }
            } catch {
                DispatchQueue.main.async {
                    result(self.fetchError(error))
                }
            }
        }
    }

    private func activate(_ result: @escaping FlutterResult) {
        Task {
            let updated = await remoteConfig.activate()
            DispatchQueue.main.async {
                result(self.stateMap(updated: updated))
            }
        }
    }

    private func fetchAndActivate(_ result: @escaping FlutterResult) {
        Task {
            do {
                let status = try await remoteConfig.fetchAndActivate()
                let updated = status == .successFetchedFromRemote
                DispatchQueue.main.async {
                    result(self.stateMap(updated: updated))
                }
            } catch {
                DispatchQueue.main.async {
                    result(self.fetchError(error))
                }
            }
        }
    }

    // MARK: - Serialization

    private func stateMap(updated: Bool? = nil) -> [String: Any] {
        var values: [String: Any] = [:]
        for (key, value) in remoteConfig.allConfigValues() {
            values[key] = [
                "value": value.stringValue,
                "source": sourceName(value.source),
            ]
        }
        var map: [String: Any] = [
            "values": values,
            "lastFetchTimeMillis":
                Int(
                    (remoteConfig.lastFetchTime?.timeIntervalSince1970 ?? 0)
                        * 1000
                ),
            "lastFetchStatus": statusName(remoteConfig.lastFetchStatus),
            "fetchTimeoutSeconds":
                Int(remoteConfig.configSettings.fetchTimeout),
            "minimumFetchIntervalSeconds":
                Int(remoteConfig.configSettings.minimumFetchInterval),
        ]
        if let updated {
            map["updated"] = updated
        }
        return map
    }

    private func statusName(_ status: RemoteConfigFetchStatus) -> String {
        switch status {
        case .success: return "SUCCESS"
        case .failure: return "FAILURE"
        case .throttled: return "THROTTLED"
        case .noFetchYet: return "NO_FETCH_YET"
        @unknown default: return "NO_FETCH_YET"
        }
    }

    private func sourceName(_ source: RemoteConfigSource) -> String {
        switch source {
        case .remote: return "remote"
        case .default: return "default"
        case .static: return "static"
        }
    }

    private func throttleEndTimeMillis(
        _ error: RemoteConfigThrottledError
    ) -> Int64 {
        return Int64(error.throttleEndTimeInterval * 1000)
    }

    private func fetchError(_ error: Error) -> FlutterError {
        if let throttled = error as? RemoteConfigThrottledError {
            return FlutterError(
                code: "throttled",
                message: throttled.message,
                details: [
                    "throttleEndTimeMillis":
                        NSNumber(value: throttleEndTimeMillis(throttled))
                ]
            )
        }
        let message =
            (error as? RemoteConfigFetchError)?.message
            ?? error.localizedDescription
        return FlutterError(
            code: "fetch_failed",
            message: message,
            details: nil
        )
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    // MARK: - Config update listener

    private func registerUpdateListener() {
        guard updateRegistration == nil else { return }
        // Native 1.4.1 reshaped this to Firebase's two-argument completion
        // `(RemoteConfigUpdate?, Error?)`, under the
        // `remoteConfigUpdateCompletion:` label. The error arm never fires
        // in this version — a failing fetch throws to the `fetch` caller
        // instead — and the Flutter event channel carries changed keys only,
        // so a nil update is simply not forwarded.
        updateRegistration = remoteConfig.addOnConfigUpdateListener(
            remoteConfigUpdateCompletion: { [weak self] update, _ in
                guard let update else { return }
                DispatchQueue.main.async {
                    self?.updatesSink?(Array(update.updatedKeys))
                }
            }
        )
    }
}

extension AppspikeRemoteConfigPlugin: FlutterStreamHandler {
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        updatesSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        updatesSink = nil
        return nil
    }
}
