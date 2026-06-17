#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_callkit_incoming_maintained.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_callkit_incoming_maintained'
  s.version          = '0.0.1'
  s.summary          = 'Flutter Callkit Incoming (Maintained Fork)'
  s.description      = <<-DESC
Community-maintained fork of flutter_callkit_incoming — show CallKit incoming call UI in your Flutter app.
                       DESC
  s.homepage         = 'https://github.com/ashutosh2014/flutter_callkit_incoming'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Ashutosh Agarwal' => 'ashutoshagarwal2014@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_callkit_incoming/Sources/flutter_callkit_incoming/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'CryptoSwift'
  s.platform = :ios, '10.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'
end
