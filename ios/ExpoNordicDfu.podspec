require "json"

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name         = "ExpoNordicDfu"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = package["description"]
  s.license      = package['license']
  s.author       = package['author']
  s.homepage     = package["homepage"] || package["url"]
  s.platform     = :ios, "15.1"
  s.swift_version  = '5.4'
  # repository.url is already a .git URL prefixed with "git+", so it only needs
  # the prefix stripped. Appending ".git" produced a "...git.git" URL.
  s.source       = { :git => package["repository"]["url"].sub(/\Agit\+/, ""), :tag => s.version }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'
  s.dependency "iOSDFULibrary", "~> 4.15.3"

  # Swift/Objective-C compatibility
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
end
