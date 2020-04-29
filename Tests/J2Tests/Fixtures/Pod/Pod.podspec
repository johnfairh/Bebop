#
# Be sure to run `pod lib lint Pod.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Pod'
  s.version          = '0.1'
  s.summary          = 'Demo cocoapod for testing J2'

  s.description      = <<-DESC
A demonstration cocoapod part of J2 test fixtures.
                       DESC

  s.homepage         = 'https://github.com/johnfairh/j2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'John Fairhurst' => 'johnfairh@gmail.com' }
  s.source           = { :git => 'https://github.com/johnfairh/j2.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'
  s.macos.deployment_target = '10.14'

  s.source_files = 'Sources/Pod/*swift'
  s.swift_version = '5'
end
