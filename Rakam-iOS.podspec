Pod::Spec.new do |s|
  s.name                   = "Rakam-iOS"
  s.version                = "4.0.2"
  s.summary                = "Rakam mobile analytics iOS SDK."
  s.homepage               = "https://rakam.io"
  s.license                = { :type => "MIT" }
  s.author                 = { "Rakam" => "emre@rakam.io" }
  s.source                 = { :git => "https://github.com/rakam-io/rakam-ios.git", :tag => "v4.0.2" }
  s.ios.deployment_target  = '6.0'
  s.tvos.deployment_target = '9.0'
  s.source_files           = 'Rakam/*.{h,m}'
  s.requires_arc           = true
  s.library 	           = 'sqlite3.0'
end
