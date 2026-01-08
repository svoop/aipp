require 'bundler/gem_tasks'

require 'minitest/test_task'

Minitest::TestTask.create(:test) do |t|
  t.test_globs = ["spec/**/*_spec.rb"]
  t.verbose = false
  t.warning = !ENV['RUBYOPT']&.match?(/-W0/)
end

Rake::Task[:test].enhance do
  if ENV['RUBYOPT']&.match?(/-W0/)
    puts "⚠️  Ruby warnings are disabled, remove -W0 from RUBYOPT to enable."
  end
end

desc "Serve documentation on http://localhost:8808"
task :yard do
  server = Thread.new do
    `rm -rf .yardoc`
    `yard server -r`
  end
  sleep 1
  `open http://localhost:8808`
  server.join
end

task default: :test
