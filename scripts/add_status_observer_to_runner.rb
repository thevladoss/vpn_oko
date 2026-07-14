require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

runner = project.targets.find { |t| t.name == 'Runner' }
abort('Runner target not found') unless runner

if runner.source_build_phase.files.any? { |f| f.display_name == 'VpnStatusObserver.swift' }
  puts 'VpnStatusObserver.swift already in Runner sources, nothing to do'
  exit 0
end

bridge_group = project.main_group.recursive_children.find do |child|
  child.is_a?(Xcodeproj::Project::Object::PBXGroup) && child.display_name == 'Bridge'
end
abort('Bridge group not found') unless bridge_group

file_ref = bridge_group.files.find { |f| f.display_name == 'VpnStatusObserver.swift' }
file_ref ||= bridge_group.new_file('VpnStatusObserver.swift')

runner.source_build_phase.add_file_reference(file_ref)

project.save
puts 'VpnStatusObserver.swift added to Runner sources'
