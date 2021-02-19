require 'bundler/gem_tasks'

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.test_files = FileList['spec/lib/**/*_spec.rb']
  t.verbose = false
  t.warning = !!ENV['TEST_WARNINGS']
end

namespace :build do
  desc "Build checksums of all gems in pkg directory"
  task :checksum do
    require 'digest/sha2'
    Dir.mkdir('checksum') unless Dir.exist?('checksum')
    Dir.glob('*.gem', base: 'pkg').each do |gem|
      checksum = Digest::SHA512.new.hexdigest(File.read("pkg/#{gem}"))
      File.open("checksum/#{gem}.sha512", 'w') { _1.write(checksum) }
    end
  end
end

Rake::Task[:test].enhance do
  unless ENV['TEST_WARNINGS']
    puts "Ruby warnings disabled, set TEST_WARNINGS environment variable to enable."
  end
end

task default: :test
