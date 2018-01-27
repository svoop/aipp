# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aipp/version'

Gem::Specification.new do |spec|
  spec.name          = 'aipp'
  spec.version       = AIPP::VERSION
  spec.authors       = ['Sven Schwyn']
  spec.email         = ['ruby@bitcetera.com']
  spec.description   = %q(Parser for Aeronautical Information Publications (AIP).)
  spec.summary       = %q(Parser for Aeronautical Information Publications (AIP).)
  spec.homepage      = 'https://github.com/svoop/aipp'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.5'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'minitest-sound'
  spec.add_development_dependency 'minitest-matchers'
  spec.add_development_dependency 'guard'
  spec.add_development_dependency 'guard-minitest'

  spec.add_runtime_dependency 'aixm', '~> 0', '>= 0.2.3'
  spec.add_runtime_dependency 'nokogiri', '~> 1'
  spec.add_runtime_dependency 'nokogumbo', '~> 1'
  spec.add_runtime_dependency 'pry', '~> 0'
end
