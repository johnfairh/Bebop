#!/usr/bin/env ruby

#  podsetup.rb
#  J2Lib
#
#  Copyright 2020 J2 Authors
#  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
#
#  Wrapper script to unpack a cocoapods build environment so we
#  can run xcodebuild via sourcekitten over the targets
#
#  Derived almost entirely from the jazzy version.
#  We grab a lot less metadata from the podspec - not sure how valuable
#  that really is.

require 'cocoapods'
require 'pathname'
require 'json'

if ARGV.length != 1
  $stderr.puts "Expected one arg, got #{ARGV}"
  return 1
end

params = JSON.parse(File.read(ARGV[0]), symbolize_names: true)
unless params[:podspec] && params[:tmpdir] && params[:response]
  $stderr.puts "Missing keys in input json: #{params}"
  return 2
end

podspec_path = Pathname.new(params[:podspec])
tmpdir = Pathname.new(params[:tmpdir])
pod_sources = params[:sources] || []
response_path = Pathname.new(params[:response])

podspec = Pod::Specification.from_file(podspec_path)

# slightly less grotty than my jazzy version!
if podspec.respond_to?('swift_versions')
  swift_version = podspec.swift_versions.max
else
  swift_version = podspec.swift_version
end

podfile = Pod::Podfile.new do
  pod_sources.each { |src| source src }

  install! 'cocoapods',
    integrate_targets: false,
    deterministic_uuids: false

  [podspec, *podspec.recursive_subspecs].each do |ss|
    next if ss.test_specification

    ss.available_platforms.each do |p|
      target("J2-#{ss.name.gsub('/', '__')}-#{p.name}") do
        use_frameworks!
        platform p.name, p.deployment_target
        pod ss.name, path: podspec_path.parent
        current_target_definition.swift_version = swift_version || '5'
      end
    end
  end
end

Pod::Config.instance.with_changes(installation_root: tmpdir,
                                  verbose: false) do
  sandbox = Pod::Sandbox.new(Pod::Config.instance.sandbox_root)
  installer = Pod::Installer.new(sandbox, podfile)
  installer.install!

  targets = installer.pod_targets
    .select { |pt| pt.pod_name == podspec.root.name }
    .map { |t| [t.label, "#{t.platform.to_s}+"] }

  output = {
    module: podspec.module_name,
    root: sandbox.root,
    targets: Hash[targets]
  }
  File.write(response_path, output.to_json)
end

return 0
