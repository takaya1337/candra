# Adds the RunnerUITests target (the store screenshots, taken on the
# phone by XCUITest) and a shared scheme "Shots" that tests it in the
# Release configuration, to Runner.xcodeproj. Run once, from app/ios:
#
#   GEM_HOME=$(brew --prefix cocoapods)/libexec ruby tool/add_ui_tests_target.rb
#
# It does nothing if the target is already there. What the test does:
# RunnerUITests/StoreScreenshots.swift; how it is run:
# app/tool/store_screenshots.sh.
require 'xcodeproj'

TEAM = ENV.fetch('DEVELOPMENT_TEAM', '')
project = Xcodeproj::Project.open('Runner.xcodeproj')
abort 'RunnerUITests is already in the project.' if project.targets.any? { |t| t.name == 'RunnerUITests' }

runner = project.targets.find { |t| t.name == 'Runner' }
tests = project.new_target(:ui_test_bundle, 'RunnerUITests', :ios, '15.0')
# Flutter builds three ways; a new target is made with two.
tests.add_build_configuration('Profile', :release) unless tests.build_configurations.any? { |c| c.name == 'Profile' }

group = project.main_group.new_group('RunnerUITests', 'RunnerUITests')
tests.add_file_references([group.new_file('StoreScreenshots.swift')])

tests.build_configurations.each do |config|
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.suryamajapahit.candra.RunnerUITests',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'CODE_SIGN_STYLE' => 'Automatic',
    'DEVELOPMENT_TEAM' => TEAM,
    'SWIFT_VERSION' => '5.0',
    'IPHONEOS_DEPLOYMENT_TARGET' => '15.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'TEST_TARGET_NAME' => 'Runner',
    'MARKETING_VERSION' => '1.0',
    'CURRENT_PROJECT_VERSION' => '1'
  )
end
tests.add_dependency(runner)
project.save

# The scheme: Runner's own (with Flutter's prepare step), its tests
# swapped for the screenshots, in Release: a debug Flutter build will not
# start without a debugger attached, and a profile build publishes its
# Dart VM service, for which iOS puts up the local network prompt over
# the first screenshots.
schemes = 'Runner.xcodeproj/xcshareddata/xcschemes'
scheme = File.read("#{schemes}/Runner.xcscheme")
scheme.sub!(/(<TestAction\s+buildConfiguration = )"Debug"/, '\1"Release"')
scheme.sub!(/<Testables>.*<\/Testables>/m, <<~XML.rstrip)
  <Testables>
           <TestableReference
              skipped = "NO"
              parallelizable = "NO">
              <BuildableReference
                 BuildableIdentifier = "primary"
                 BlueprintIdentifier = "#{tests.uuid}"
                 BuildableName = "RunnerUITests.xctest"
                 BlueprintName = "RunnerUITests"
                 ReferencedContainer = "container:Runner.xcodeproj">
              </BuildableReference>
           </TestableReference>
        </Testables>
XML
File.write("#{schemes}/Shots.xcscheme", scheme)
puts 'Added RunnerUITests and the Shots scheme.'
