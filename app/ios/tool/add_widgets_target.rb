# Adds the CandraWidgets extension (lock screen widgets and the Dynamic
# Island) to Runner.xcodeproj. Run once, from app/ios:
#
#   GEM_HOME=$(brew --prefix cocoapods)/libexec ruby tool/add_widgets_target.rb
#
# It does nothing if the target is already there.
require 'xcodeproj'

TEAM = ENV.fetch('DEVELOPMENT_TEAM', '')
project = Xcodeproj::Project.open('Runner.xcodeproj')
abort 'CandraWidgets is already in the project.' if project.targets.any? { |t| t.name == 'CandraWidgets' }

runner = project.targets.find { |t| t.name == 'Runner' }
extension = project.new_target(:app_extension, 'CandraWidgets', :ios, '17.0')
# Flutter builds three ways; a new target is made with two.
extension.add_build_configuration('Profile', :release) unless extension.build_configurations.any? { |c| c.name == 'Profile' }

widgets = project.main_group.new_group('CandraWidgets', 'CandraWidgets')
shared = project.main_group.new_group('Shared', 'Shared')
sources = %w[CandraWidgetsBundle.swift DayWidget.swift LiveActivity.swift].map { |name| widgets.new_file(name) }
extension.add_resources([widgets.new_file('Assets.xcassets')])
widgets.new_file('Info.plist')
widgets.new_file('CandraWidgets.entitlements')
activity = shared.new_file('CandraActivity.swift')
extension.add_file_references(sources + [activity])
runner.add_file_references([activity])
runner_group = project.main_group.children.find { |g| g.display_name == 'Runner' }
runner_group.new_file('Runner.entitlements')

extension.build_configurations.each do |config|
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.suryamajapahit.candra.CandraWidgets',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => 'CandraWidgets/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'CODE_SIGN_ENTITLEMENTS' => 'CandraWidgets/CandraWidgets.entitlements',
    'CODE_SIGN_STYLE' => 'Automatic',
    'DEVELOPMENT_TEAM' => TEAM,
    'SWIFT_VERSION' => '5.0',
    'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'MARKETING_VERSION' => '1.0.0',
    'CURRENT_PROJECT_VERSION' => '2',
    'SKIP_INSTALL' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  )
end
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

runner.add_dependency(extension)
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embedded = embed.add_file_reference(extension.product_reference)
embedded.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
# Before Flutter's own script phases, or Xcode finds a cycle.
thin = runner.build_phases.index { |phase| phase.respond_to?(:name) && phase.name == 'Thin Binary' }
runner.build_phases.move(embed, thin) if thin

project.save
puts 'Added CandraWidgets.'
