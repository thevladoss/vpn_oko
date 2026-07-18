require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

targets = %w[DemoCooldownStore.swift DemoLimitTimer.swift]

removed = []

project.files.dup.each do |file|
  next unless targets.include?(file.display_name)

  file.referrers.grep(Xcodeproj::Project::Object::PBXBuildFile).dup.each do |build_file|
    build_file.remove_from_project
    removed << "build_file #{file.display_name}"
  end

  file.remove_from_project
  removed << "file_ref #{file.display_name}"
end

if removed.empty?
  puts 'nothing to remove'
else
  project.save
  puts "removed: #{removed.join(', ')}"
end
