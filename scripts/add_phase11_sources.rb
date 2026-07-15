require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

sources = {
  'Shared/AppGroup.swift' => %w[Runner PacketTunnel],
  'Shared/DemoCooldownStore.swift' => %w[Runner PacketTunnel],
  'PacketTunnel/RunBlocking.swift' => %w[PacketTunnel],
  'PacketTunnel/OkoPlatformInterface.swift' => %w[PacketTunnel],
  'Bridge/TrafficLogClient.swift' => %w[Runner]
}

def find_or_create_group(project, name)
  existing = project.main_group.recursive_children.find do |child|
    child.is_a?(Xcodeproj::Project::Object::PBXGroup) && child.display_name == name
  end
  existing || project.main_group.new_group(name, name)
end

changed = false

sources.each do |rel_path, target_names|
  group_name, file_name = rel_path.split('/', 2)
  group = find_or_create_group(project, group_name)

  file_ref = group.files.find { |f| f.display_name == file_name }
  unless file_ref
    file_ref = group.new_file(file_name)
    changed = true
  end

  target_names.each do |target_name|
    target = project.targets.find { |t| t.name == target_name }
    abort("#{target_name} target not found") unless target
    in_phase = target.source_build_phase.files.any? do |build_file|
      build_file.file_ref&.display_name == file_name
    end
    next if in_phase

    target.source_build_phase.add_file_reference(file_ref)
    changed = true
  end
end

if changed
  project.save
  puts 'phase 11 sources registered'
else
  puts 'phase 11 sources already registered, nothing to do'
end
