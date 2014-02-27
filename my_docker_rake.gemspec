# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'my_docker_rake/version'

Gem::Specification.new do |spec|
  spec.name          = "my_docker_rake"
  spec.version       = MyDockerRake::VERSION
  spec.authors       = ["hyone"]
  spec.email         = ["hyone.development@gmail.com"]
  spec.summary       = %q{provide useful rake tasks to build and run a docker project}
  spec.description   = %q{provide useful rake tasks to build and run a docker project}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'rake'

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rspec'
end
