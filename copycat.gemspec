# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "copycat/version"

Gem::Specification.new do |s|
  s.name        = "copycat"
  s.version     = Copycat::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jason Dew", "Gary Fredericks"]
  s.email       = ["jason.dew@gmail.com", "gfredericks@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Plagiarism detector/generator}
  s.description = %q{Plagiarism detector/generator}

  s.rubyforge_project = "copycat"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "rubytree"
end
