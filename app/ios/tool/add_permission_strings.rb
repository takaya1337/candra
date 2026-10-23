# Adds Runner/id.lproj/InfoPlist.strings (the permission prompts in
# Indonesian, made by tool/permission_strings.sh) to the Runner target as
# a localised resource, and Indonesian to the project's languages. Run
# once, from app/ios:
#
#   GEM_HOME=$(brew --prefix cocoapods)/libexec ruby tool/add_permission_strings.rb
require 'xcodeproj'

project = Xcodeproj::Project.open('Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
group = project.main_group.children.find { |g| g.display_name == 'Runner' }
abort 'No Runner target or group.' unless runner && group

regions = project.root_object.known_regions
regions << 'id' unless regions.include?('id')

if group.children.any? { |c| c.display_name == 'InfoPlist.strings' }
  puts 'InfoPlist.strings is already there.'
else
  variant = group.new_variant_group('InfoPlist.strings')
  file = variant.new_file('id.lproj/InfoPlist.strings')
  file.name = 'id'
  runner.add_resources([variant])
  puts 'InfoPlist.strings (id) added.'
end
project.save
