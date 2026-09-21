package dev.appspike.appspike_remote_config

import android.content.Context
import android.util.Log
import dev.appspike.AppSpike
import dev.appspike.InitResult
import dev.appspike.remoteconfig.AppSpikeRemoteConfig
import dev.appspike.remoteconfig.ConfigUpdateListenerRegistration
import dev.appspike.remoteconfig.CustomSignals
import dev.appspike.remoteconfig.RemoteConfigFetchException
import dev.appspike.remoteconfig.RemoteConfigSettings
import dev.appspike.remoteconfig.RemoteConfigThrottledException
import dev.appspike.remoteconfig.ValueSource
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class AppspikeRemoteConfigPlugin :
    FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var applicationContext: Context

    private val remoteConfig = AppSpikeRemoteConfig

    private val mainScope = CoroutineScope(
        SupervisorJob() +
            Dispatchers.Main +
            CoroutineExceptionHandler { _, error ->
                Log.e(TAG, "Unhandled error in the Remote Config bridge", error)
            }
    )
    private var eventSink: EventChannel.EventSink? = null
    private var updateRegistration: ConfigUpdateListenerRegistration? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "dev.appspike/remote_config")
        channel.setMethodCallHandler(this)
        eventChannel =
            EventChannel(binding.binaryMessenger, "dev.appspike/remote_config/updates")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        updateRegistration?.remove()
        updateRegistration = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "ensureInitialized" -> launchGuarded(result) {
                remoteConfig.ensureInitialized()
                result.success(stateMap())
            }
            "setDefaults" -> {
                val defaults = call.argument<Map<String, Any?>>("defaults") ?: emptyMap()
                remoteConfig.setDefaults(defaults)
                result.success(stateMap())
            }
            "setConfigSettings" -> {
                val timeout = longArg(call, "fetchTimeoutSeconds") ?: 60L
                val interval = longArg(call, "minimumFetchIntervalSeconds") ?: 43_200L
                remoteConfig.setConfigSettings(
                    RemoteConfigSettings(
                        minimumFetchIntervalSeconds = interval,
                        fetchTimeoutSeconds = timeout,
                    )
                )
                result.success(stateMap())
            }
            "setCustomSignals" -> setCustomSignals(call, result)
            "fetch" -> fetch(call, result)
            "activate" -> launchGuarded(result) {
                val updated = remoteConfig.activate()
                result.success(stateMap(updated = updated))
            }
            "fetchAndActivate" -> fetchAndActivate(result)
            "getState" -> result.success(stateMap())
            "reset" -> {
                remoteConfig.reset()
                result.success(stateMap())
            }
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: Result) {
        val apiKey = call.argument<String>("apiKey") ?: ""
        registerUpdateListener()
        AppSpike.initialize(
            context = applicationContext,
            apiKey = apiKey,
            modules = listOf(remoteConfig),
        ) { initResult ->
            launchGuarded(result) {
                when (initResult) {
                    is InitResult.Success -> result.success(mapOf("status" to "success"))
                    is InitResult.Error -> result.success(
                        mapOf("status" to "error", "message" to initResult.message)
                    )
                }
            }
        }
    }

    private fun setCustomSignals(call: MethodCall, result: Result) {
        val signals = call.argument<Map<String, Any?>>("signals") ?: emptyMap()
        val builder = CustomSignals.Builder()
        for ((key, value) in signals) {
            builder.put(key, value?.toString())
        }
        launchGuarded(result) {
            remoteConfig.setCustomSignals(builder.build())
            result.success(null)
        }
    }

    private fun fetch(call: MethodCall, result: Result) {
        val override = longArg(call, "minimumFetchIntervalSeconds")
        launchGuarded(result) {
            remoteConfig.fetch(override)
            result.success(stateMap())
        }
    }

    private fun fetchAndActivate(result: Result) {
        launchGuarded(result) {
            val updated = remoteConfig.fetchAndActivate()
            result.success(stateMap(updated = updated))
        }
    }

    private fun launchGuarded(result: Result, block: suspend () -> Unit) {
        mainScope.launch {
            try {
                block()
            } catch (error: Throwable) {
                fail(result, error)
            }
        }
    }

    private fun stateMap(updated: Boolean? = null): Map<String, Any?> {
        val values = HashMap<String, Any?>()
        for ((key, value) in remoteConfig.getAll()) {
            values[key] = mapOf(
                "value" to value.asString(),
                "source" to sourceName(value.getSource()),
            )
        }
        val info = remoteConfig.getInfo()
        val map = HashMap<String, Any?>()
        map["values"] = values
        map["lastFetchTimeMillis"] = info.lastFetchTimeMillis
        map["lastFetchStatus"] = info.lastFetchStatus.name
        map["fetchTimeoutSeconds"] = info.configSettings.fetchTimeoutSeconds
        map["minimumFetchIntervalSeconds"] =
            info.configSettings.minimumFetchIntervalSeconds
        if (updated != null) map["updated"] = updated
        return map
    }

    private fun sourceName(source: ValueSource): String = when (source) {
        ValueSource.REMOTE -> "remote"
        ValueSource.DEFAULT -> "default"
        ValueSource.STATIC -> "static"
    }

    private fun fail(result: Result, error: Throwable) {
        val details = if (error is RemoteConfigThrottledException) {
            mapOf("throttleEndTimeMillis" to error.throttleEndTimeMillis)
        } else {
            null
        }
        result.error(errorCode(error), error.message, details)
    }

    private fun errorCode(error: Throwable): String = when (error) {
        is RemoteConfigThrottledException -> "throttled"
        is RemoteConfigFetchException -> "fetch_failed"
        else -> "fetch_failed"
    }

    private fun longArg(call: MethodCall, name: String): Long? =
        when (val value = call.argument<Any?>(name)) {
            is Int -> value.toLong()
            is Long -> value
            is Number -> value.toLong()
            else -> null
        }

    private fun registerUpdateListener() {
        if (updateRegistration != null) return
        // Native 1.4.1 reshaped the listener to Firebase's two-method interface,
        // so the lambda overload now hands over a `ConfigUpdate` wrapper rather
        // than the bare key set.
        updateRegistration = remoteConfig.addOnConfigUpdateListener { update ->
            mainScope.launch {
                // No Result to fail here: a broken sink must not take the app
                // down, and the next activation will deliver its own keys.
                try {
                    eventSink?.success(update.updatedKeys.toList())
                } catch (error: Throwable) {
                    Log.e(TAG, "Failed to deliver a config update to Flutter", error)
                }
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private companion object {
        private const val TAG = "AppSpikeRemoteConfig"
    }
}
