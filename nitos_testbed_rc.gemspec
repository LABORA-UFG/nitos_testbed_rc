# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "version.rb"

Gem::Specification.new do |s|
  s.name        = "nitos_testbed_rc"
  s.version     = NITOS::TestbedRc::VERSION
  s.authors     = ["NITOS"]
  s.email       = ["nitlab@inf.uth.gr"]
  s.homepage    = "http://nitlab.inf.uth.gr"
  s.summary     = %q{NITOS testbed resource controllers.}
  s.description = %q{NITOS testbed resource controllers that support a. Chassis manager cards, b. frisbee clients and servers for loading and saving images and c. user creation.}

  s.rubyforge_project = "nitos_testbed_rc"

  s.files         = `git ls-files`.split("\n")
  # s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_runtime_dependency "omf_common", "~> 6.2.4"
  s.add_runtime_dependency "omf_rc", "~> 6.2.4"
  s.add_runtime_dependency "nokogiri", "~> 1.6.0"
  s.add_runtime_dependency "progress_bar", "~> 1.0.3"
  s.add_runtime_dependency "net-ssh", "~> 2.8.0"
end
