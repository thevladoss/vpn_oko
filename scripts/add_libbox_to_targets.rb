require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

framework_name = 'Libbox.xcframework'
framework_path = 'Frameworks/Libbox.xcframework'
search_path = '$(SRCROOT)/Frameworks'
system_frameworks = %w[UIKit Security SystemConfiguration Network]
system_libs = %w[-lresolv]
target_names = %w[Runner PacketTunnel]

targets = target_names.map do |name|
  target = project.targets.find { |t| t.name == name }
  abort("#{name} target not found") unless target
  target
end

frameworks_group = project.main_group.recursive_children.find do |child|
  child.is_a?(Xcodeproj::Project::Object::PBXGroup) && child.display_name == 'Frameworks'
end
frameworks_group ||= project.main_group.new_group('Frameworks')

changed = false

file_ref = frameworks_group.files.find { |f| f.display_name == framework_name }
unless file_ref
  file_ref = frameworks_group.new_reference(framework_path)
  file_ref.source_tree = 'SOURCE_ROOT'
  file_ref.path = framework_path
  changed = true
end

targets.each do |target|
  unless target.frameworks_build_phase.files.any? { |bf| bf.display_name == framework_name }
    target.frameworks_build_phase.add_file_reference(file_ref, true)
    changed = true
  end

  target.build_configurations.each do |config|
    current = config.build_settings['FRAMEWORK_SEARCH_PATHS']
    paths = case current
            when Array then current.dup
            when nil then []
            else [current]
            end
    unless paths.include?(search_path)
      paths.unshift('$(inherited)') unless paths.include?('$(inherited)')
      paths << search_path
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] = paths
      changed = true
    end

    ldflags = config.build_settings['OTHER_LDFLAGS']
    original = case ldflags
               when Array then ldflags.dup
               when nil then []
               else ldflags.to_s.split(' ')
               end
    flags = original.dup
    flags.unshift('$(inherited)') unless flags.include?('$(inherited)')
    system_frameworks.each do |name|
      linked = flags.each_cons(2).any? { |a, b| a == '-framework' && b == name }
      flags.push('-framework', name) unless linked
    end
    system_libs.each { |lib| flags << lib unless flags.include?(lib) }
    if flags != original
      config.build_settings['OTHER_LDFLAGS'] = flags
      changed = true
    end
  end
end

if changed
  project.save
  puts 'Libbox.xcframework linked into Runner and PacketTunnel'
else
  puts 'Libbox.xcframework already linked, nothing to do'
end
