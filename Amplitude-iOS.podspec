Pod::Spec.new do |s|
  s.name                   = "Amplitude-iOS"
  s.version                = "3.14.0"
  s.summary                = "Rakam mobile analytics iOS SDK."
  s.homepage               = "https://rakam.io"
  s.license                = { :type => "MIT" }
  s.author                 = { "Rakam" => "emre@rakam.io" }
  s.source                 = { :git => "https://github.com/rakam-io/rakam-ios.git", :tag => "v3.14.0" }
  s.ios.deployment_target  = '6.0'
  s.tvos.deployment_target = '9.0'
  s.source_files           = 'Amplitude/*.{h,m}'
  s.resources              = 'Amplitude/*.der'
  s.requires_arc           = true
  s.library 	           = 'sqlite3.0'
end
