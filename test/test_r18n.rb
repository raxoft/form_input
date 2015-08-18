# encoding: UTF-8

require 'form_input'
require 'form_input/r18n'

class TestR18nForm < FormInput
  param! :q, min_size: 2, max_size: 8,
    min_bytesize: 3, max_bytesize: 6,
    match: /\A[A-Z]+\z/, reject: /[a-z]/
  array! :a, INTEGER_ARGS, min_count: 2, max_count: 3
  hash :h, min_key: 1, max_key: 7
  hash :hh, match_key: /\A[a-z]+\z/
  param :int, INTEGER_ARGS, min: 5, max: 10
  param :float, FLOAT_ARGS, inf: 0, sup: 1
  param :msg, "Message"
end

describe FormInput do

  TESTS = [
    [ "", q: "ABC", a: [ 1, 2 ] ],
    [ "q is required", q: nil ],
    [ "a are required", a: nil ],
    [ "a is not an array", a: 2 ],
    [ "h is not a hash", h: 3 ],
    [ "hh contains invalid key", hh: { 1 => 2 } ],
    [ "h contains invalid key", h: { 'foo' => 'bar' } ],
    [ "h contains too small key", h: { 0 => 0 } ],
    [ "h contains too large key", h: { 10 => 0 } ],
    [ "a must have at least 2 elements", a: [ 1 ] ],
    [ "a must have at most 3 elements", a: [ 1, 2, 3, 4 ] ],
    [ "int like this is not valid", int: 'foo' ],
    [ "a contains invalid value", a: [ 10, 'bar' ] ],
    [ "int must be at least 5", int: 0 ],
    [ "int must be at most 10", int: 20 ],
    [ "float must be greater than 0", float: 0.0 ],
    [ "float must be less than 1", float: 1.0 ],
    [ "q is not a string", q: [ 1 ] ],
    [ "h contains invalid value", h: { 5 => 5 } ],
    [ "h uses invalid encoding", h: { 5 => 255.chr.force_encoding( Encoding::UTF_8 ) } ],
    [ "h contains invalid characters", h: { 5 => "\f" } ],
    [ "q must have at least 2 characters", q: "0" ],
    [ "q must have at most 8 characters", q: "123456789" ],
    [ "q must have at least 3 bytes", q: "01" ],
    [ "q must have at most 6 bytes", q: "1234567" ],
    [ "q like this is not allowed", q: "abcd" ],
    [ "q like this is not valid", q: "12345" ],
  ]

  def set_locale( code )
    R18n.set( code, [ "#{__FILE__}/../r18n", FormInput.translations_path ] )
  end
  
  def test_translations
    for reference, hash in TESTS
      defaults ||= hash
      hash = defaults.merge( hash )
      f = TestR18nForm.new( hash )
      yield( f.error_messages.join( ':' ), reference )
    end
  end
  
  should 'use builtin error messages by default' do
    R18n.get.should.be.nil
    test_translations do |msg, reference|
      msg.should == reference
    end
  end

  should 'localize builtin error messages for supported locales' do
    set_locale( 'en' ).locale.code.should == 'en'
    test_translations do |msg, reference|
      msg.should == reference
    end

    set_locale( 'xx' ).locale.code.should == 'xx'
    test_translations do |msg, reference|
      msg.should =~ /^{{.*}}$/ unless msg.empty?
      msg.should =~ /^{{.*{{.*}}}}$/ if msg =~ /\d \w/
      msg.gsub( /{{|}}/, '' ).should == reference
    end
  end

  should 'fallback to English error messages for unsupported locales' do
    set_locale( 'zz' ).locale.code.should == 'en'
    test_translations do |msg, reference|
      msg.should == reference
    end
  end
  
  should 'provide scope name for automatic translations' do
    TestR18nForm.translation_name.should == 'test_r18n_form'
  end
  
  should 'automatically translate string options when possible' do
    set_locale( 'cs' ).locale.code.should == 'cs'
    TestR18nForm.new.param( :msg ).title.should == 'Zpráva'
  end
  
  should 'use default string options for unsupported locales' do
    set_locale( 'en' ).locale.code.should == 'en'
    TestR18nForm.new.param( :msg ).title.should == 'Message'
  end

end

# EOF #
