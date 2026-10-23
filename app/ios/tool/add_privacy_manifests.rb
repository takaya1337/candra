# Adds the privacy manifests (Runner/PrivacyInfo.xcprivacy and
# CandraWidgets/PrivacyInfo.xcprivacy) to their targets' resources in
# Runner.xcodeproj. Run once, from app/ios:
#
#   GEM_HOME=$(brew --prefix cocoapods)/libexec ruby tool/add_privacy_manifests.rb
#
# It leaves a target alone that already has its manifest.
require 'xcodeproj'

project = Xcodeproj::Project.open('Runner.xcodeproj')
{ 'Runner' => 'Runner', 'CandraWidgets' => 'CandraWidgets' }.each do |target_name, group_name|
  target = project.targets.find { |t| t.name == target_name }
  group = project.main_group.children.find { |g| g.display_name == group_name }
  abort "No #{target_name} target or #{group_name} group." unless target && group
  if target.resources_build_phase.files.any? { |f| f.display_name == 'PrivacyInfo.xcprivacy' }
    puts "#{target_name} already has its manifest."
    next
  end
  file = group.files.find { |f| f.display_name == 'PrivacyInfo.xcprivacy' } ||
         group.new_file('PrivacyInfo.xcprivacy')
  target.add_resources([file])
  puts "#{target_name}: manifest added."
end
project.save
