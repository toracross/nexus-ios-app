# Uncomment this line to define a global platform for your project
platform :ios, '9.0'
# Uncomment this line if you're using Swift
use_frameworks!

target 'Nexus' do

pod 'MaterialKit', :git => 'https://github.com/pontago/MaterialKit.git', :branch => 'swift3'
pod 'ReachabilitySwift', '~> 3'
pod 'SVWebViewController', :git => 'https://github.com/TransitApp/SVWebViewController', :branch => 'master'
pod 'APAddressBook/Swift'
pod 'EasyMapping'
pod 'APContactEasyMapping'

end

target 'NexusTests' do

end

target 'NexusUITests' do

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
    end
  end
end