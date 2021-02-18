# coding: utf-8
require_relative 'lib/aipp/version'

Gem::Specification.new do |spec|
  spec.name        = 'aipp'
  spec.version     = AIPP::VERSION
  spec.summary     = 'Parser for aeronautical information publications'
  spec.description = <<~END
    Parse public AIP (Aeronautical Information Publication) and convert the data
    to either AIXM (Aeronautical Information Exchange Model) or OFMX (Open
    FlightMaps eXchange).
  END
  spec.authors     = ['Sven Schwyn']
  spec.email       = ['ruby@bitcetera.com']
  spec.homepage    = 'https://github.com/svoop/aipp'
  spec.license     = 'MIT'

  spec.metadata = {
    'homepage_uri'      => spec.homepage,
    'changelog_uri'     => 'https://github.com/svoop/aipp/blob/main/CHANGELOG.md',
    'source_code_uri'   => 'https://github.com/svoop/aipp',
    'documentation_uri' => 'https://www.rubydoc.info/gems/aipp',
    'bug_tracker_uri'   => 'https://github.com/svoop/aipp/issues'
  }

  spec.files         = Dir['lib/**/*']
  spec.require_paths = %w(lib)
  spec.bindir        = 'exe'
  spec.executables   = %w(aip2aixm aip2ofmx)

  spec.cert_chain  = ["certs/svoop.pem"]
  spec.signing_key = File.expand_path(ENV['GEM_SIGNING_KEY']) if ENV['GEM_SIGNING_KEY']

  spec.extra_rdoc_files = Dir['README.md', 'CHANGELOG.md', 'LICENSE.txt']
  spec.rdoc_options    += [
    '--title', 'AIP Parser and Converter',
    '--main', 'README.md',
    '--line-numbers',
    '--inline-source',
    '--quiet'
  ]

  spec.required_ruby_version = '>= 2.7.0'

  spec.add_runtime_dependency 'aixm', '>= 0.3.10'
  spec.add_runtime_dependency 'activesupport', '~> 5'
  spec.add_runtime_dependency 'nokogiri', '~> 1'
  spec.add_runtime_dependency 'nokogumbo', '~> 2'
  spec.add_runtime_dependency 'pdf-reader', '~> 2'
  spec.add_runtime_dependency 'json', '~> 2'
  spec.add_runtime_dependency 'rubyzip', '~> 2'
  spec.add_runtime_dependency 'colorize', '~> 0'
  spec.add_runtime_dependency 'pry', '~> 0'
  spec.add_runtime_dependency 'pry-rescue', '~> 1'
  spec.add_runtime_dependency 'pry-stack_explorer', '~> 0'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'minitest-sound'
  spec.add_development_dependency 'minitest-focus'
  spec.add_development_dependency 'minitest-matchers'
  spec.add_development_dependency 'spy'
  spec.add_development_dependency 'guard'
  spec.add_development_dependency 'guard-minitest'
end
