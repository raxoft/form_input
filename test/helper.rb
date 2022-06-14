# Test helper.

# Test coverage if enabled.

def jruby?
  defined?( RUBY_ENGINE ) and RUBY_ENGINE == 'jruby'
end

begin
  require 'codeclimate-test-reporter'
  ENV[ 'COVERAGE' ] = 'on'
rescue LoadError
end unless jruby?

if ENV[ 'COVERAGE' ]
  require 'simplecov'
  SimpleCov.start do
    add_filter 'bundler'
  end
end

# EOF #
