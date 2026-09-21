#
# AppSpike Remote Config Flutter plugin — iOS.
# The evaluation/fetch/persistence engine ships as prebuilt XCFrameworks
# vendored below; this pod only bridges them to the Flutter channel.
#
Pod::Spec.new do |s|
  s.name             = 'appspike_remote_config'
  s.version          = '1.4.5'
  s.summary          = 'AppSpike Remote Config for Flutter (iOS).'
  s.description      = <<-DESC
Firebase Remote Config-compatible remote configuration for Flutter,
backed by the native AppSpike Remote Config XCFramework.
                       DESC
  s.homepage         = 'https://github.com/pydetech/appspike-sdk-flutter-dist'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'AppSpike' => 'support@appspike.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.vendored_frameworks = 'Frameworks/AppSpikeSDKCore.xcframework',
                          'Frameworks/AppSpikeSDKRemoteConfig.xcframework'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # The vendored frameworks ship interface-only Swift modules built by
    # the release toolchain. Xcode's explicit-module builds fail to add
    # SwiftOnoneSupport to the nested compile-from-interface job for
    # them ("missing required module 'SwiftOnoneSupport'"); implicit
    # module loading resolves it correctly.
    'SWIFT_ENABLE_EXPLICIT_MODULES' => 'NO'
  }
  s.swift_version = '5.0'
end
