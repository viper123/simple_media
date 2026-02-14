#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint media.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'simple_media'
  s.version          = '0.1.1'
  s.summary          = 'iOS Simple Media plugin. Supports background playback'
  s.description      = <<-DESC
Media plugin
                       DESC
  s.homepage         = 'https://hevsoft.go.ro/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Elvis Rusu' => 'hevsoft@gmail.com' }
  s.source           = { :path => '.' }
  s.platform  = :ios, '15.0'
  s.source_files = 'Classes/**/*'

  s.dependency 'Flutter'
  s.dependency 'Kingfisher','~> 8.6.0'


  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'media_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
