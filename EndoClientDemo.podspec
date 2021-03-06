#
# Be sure to run `pod lib lint EndoClientDemo.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'EndoClientDemo'
  s.version          = '0.1.5'
  s.summary          = 'A Sample project using the EndoClient Framework.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'A Sample project using the EndoClient Framework. You can used endoStartstop,addCommand and etc commands'

  s.homepage         = 'https://github.com/kkpeerlogic/EndoClientDemo'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'kkpeerlogic' => 'kanhaiya@peerlogicsys.com' }
  s.source           = { :git => 'https://github.com/kkpeerlogic/EndoClientDemo.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '9.0'

  s.pod_target_xcconfig = {'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1 POD_CONFIGURATION_DEBUG=1 DEBUG=1 ENDO_NO_NSLOG_OVERRIDE'}

  s.source_files = 'EndoClientDemo/Classes/**/*'
  
  # s.resource_bundles = {
  #   'EndoClientDemo' => ['EndoClientDemo/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
   s.dependency 'CocoaAsyncSocket'
end
