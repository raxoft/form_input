# Test helper.

# Test coverage if enabled.

def jruby?
  defined?( RUBY_ENGINE ) and RUBY_ENGINE == 'jruby'
end

if ENV[ 'COVERAGE' ]
  require 'simplecov'
  SimpleCov.start
end

begin
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
  ENV[ 'COVERAGE' ] = 'on'
rescue LoadError
end unless jruby?

# EOF #
