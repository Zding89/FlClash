Pod::Spec.new do |s|
  s.name = 'ai_security'
  s.version = '0.1.0'
  s.summary = 'FlClash AI Keychain transport'
  s.description = s.summary
  s.homepage = 'https://github.com/chen08209/FlClash'
  s.license = { :type => 'GPL-3.0' }
  s.author = { 'FlClash' => 'FlClash' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '11.0'
  s.swift_version = '5.0'
  s.frameworks = 'Security'
end
