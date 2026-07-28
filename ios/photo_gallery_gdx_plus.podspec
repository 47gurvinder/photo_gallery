#
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint photo_gallery_gdx_plus.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'photo_gallery_gdx_plus'
  s.version          = '2.3.2'
  s.summary          = 'Retrieve images and videos from native mobile galleries.'
  s.description      = <<-DESC
A community-maintained Flutter plugin that retrieves images and videos from native Android and iOS galleries.
                       DESC
  s.homepage         = 'https://gurwinderdevx.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Wenqi Li and contributors'
  s.source           = { :path => '.' }
  s.source_files     = 'photo_gallery_gdx_plus/Sources/photo_gallery_gdx_plus/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
