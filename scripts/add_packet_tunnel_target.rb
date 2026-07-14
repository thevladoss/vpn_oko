require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

runner = project.targets.find { |t| t.name == 'Runner' }
abort('Runner target not found') unless runner

if project.targets.any? { |t| t.name == 'PacketTunnel' }
  puts 'PacketTunnel target already exists, nothing to do'
  exit 0
end

ext = project.new_target(:app_extension, 'PacketTunnel', :ios, '13.0')

ext.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.vpnOko.PacketTunnel'
  settings['PRODUCT_NAME'] = 'PacketTunnel'
  settings['INFOPLIST_FILE'] = 'PacketTunnel/Info.plist'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'PacketTunnel/PacketTunnel.entitlements'
  settings['SWIFT_VERSION'] = '5.0'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
  settings['DEVELOPMENT_TEAM'] = 'Z2GDTXHVZZ'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
  settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if config.name == 'Debug'
end

group = project.main_group.new_group('PacketTunnel', 'PacketTunnel')
swift_ref = group.new_file('PacketTunnelProvider.swift')
group.new_file('Info.plist')
group.new_file('PacketTunnel.entitlements')

ext.source_build_phase.add_file_reference(swift_ref)

runner.add_dependency(ext)

embed_phase = runner.new_copy_files_build_phase('Embed App Extensions')
embed_phase.symbol_dst_subfolder_spec = :plug_ins
embed_build_file = embed_phase.add_file_reference(ext.product_reference)
embed_build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

thin_binary_index = runner.build_phases.index do |phase|
  phase.respond_to?(:name) && phase.name == 'Thin Binary'
end
runner.build_phases.move(embed_phase, thin_binary_index) if thin_binary_index

runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

project.save
puts 'PacketTunnel target added'
