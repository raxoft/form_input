# Rake makefile.

require 'rake/testtask'

task :default => :test

desc 'Run tests'
task :test do
  sh "bacon --automatic --quiet"
end

desc 'Run tests with coverage'
task :cov do
  sh "rm -rf coverage"
  ENV['COVERAGE'] = 'on'
  Rake::Task[:test].execute
end

# EOF #
