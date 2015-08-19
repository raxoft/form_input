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
  param :msg2, "Second Message", form_title: ->{ ft.msg.title | 'Another Message' }, error_title: ->{ pt.error_title }
end

describe FormInput do

  TESTS = [
    [ '', '', q: 'ABC', a: [ 1, 2 ] ],
    [ 'q is required', 'q je povinný', q: nil ],
    [ 'a are required', 'a jsou povinné', a: nil ],
    [ 'a are not an array', 'a nejsou pole', a: 2 ],
    [ 'h are not a hash', 'h nejsou hash', h: 3 ],
    [ 'hh contain invalid key', 'hh obsahují neplatný klíč', hh: { 1 => 2 } ],
    [ 'h contain invalid key', 'h obsahují neplatný klíč', h: { 'foo' => 'bar' } ],
    [ 'h contain too small key', 'h obsahují příliš malý klíč', h: { 0 => 0 } ],
    [ 'h contain too large key', 'h obsahují příliš velký klíč', h: { 10 => 0 } ],
    [ 'a must have at least 2 elements', 'a musí mít nejméně 2 prvky', a: [ 1 ] ],
    [ 'a may have at most 3 elements', 'a smí mít nejvíce 3 prvky', a: [ 1, 2, 3, 4 ] ],
    [ 'int like this is not valid', 'int musí mít správný formát', int: 'foo' ],
    [ 'a contain invalid value', 'a obsahují neplatnou hodnotu', a: [ 10, 'bar' ] ],
    [ 'int must be at least 5', 'int musí být nejméně 5', int: 0 ],
    [ 'int may be at most 10', 'int smí být nejvíce 10', int: 20 ],
    [ 'float must be greater than 0', 'float musí být větší než 0', float: 0.0 ],
    [ 'float must be less than 1', 'float musí být menší než 1', float: 1.0 ],
    [ 'q is not a string', 'q není řetězec', q: [ 1 ] ],
    [ 'h contain invalid value', 'h obsahují neplatnou hodnotu', h: { 5 => 5 } ],
    [ 'h must use valid encoding', 'h musí mít platný encoding', h: { 5 => 255.chr.force_encoding( Encoding::UTF_8 ) } ],
    [ 'h may not contain invalid characters', 'h nesmí obsahovat zakázané znaky', h: { 5 => "\f" } ],
    [ 'q must have at least 2 characters', 'q musí mít nejméně 2 znaky', q: '0' ],
    [ 'q may have at most 8 characters', 'q smí mít nejvíce 8 znaků', q: '123456789' ],
    [ 'q must have at least 3 bytes', 'q musí mít nejméně 3 byty', q: '01' ],
    [ 'q may have at most 6 bytes', 'q smí mít nejvíce 6 bytů', q: '1234567' ],
    [ 'q like this is not allowed', 'q jako tento není povolen', q: 'abcd' ],
    [ 'q like this is not valid', 'q jako tento není platný', q: '12345' ],
  ]

  def set_locale( code )
    R18n.set( code, [ "#{__FILE__}/../r18n", FormInput.translations_path ] )
  end

  def test_translations
    for reference, translation, hash in TESTS
      defaults ||= hash
      hash = defaults.merge( hash )
      f = TestR18nForm.new( hash )
      yield( f.error_messages.join( ':' ), reference, translation )
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

    set_locale( 'cs' ).locale.code.should == 'cs'
    test_translations do |msg, reference, translation|
      msg.should == translation
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
    f = TestR18nForm.new
    p = f.param( :msg )
    p.title.should == 'Zpráva'
    p.form_title.should == 'Vaše zpráva'
    p.error_title.should == 'Parametr Zpráva'
    p[ :msg ].should == '%p není správně vyplněn'
    p[ :match_msg ].should == '%p není ve správném tvaru'
    p[ :reject_msg ].should == '%p obsahuje nepovolené znaky'
    p[ :required_msg ].should == '%p musí být vyplněn'
  end

  should 'use default string options for unsupported locales' do
    set_locale( 'en' ).locale.code.should == 'en'
    f = TestR18nForm.new
    p = f.param( :msg )
    p.title.should == 'Message'
    p.form_title.should == 'Message'
    p.error_title.should == 'Message'
    p[ :msg ].should.be.nil
    p[ :match_msg ].should.be.nil
    p[ :reject_msg ].should.be.nil
    p[ :required_msg ].should.be.nil
  end

  should 'provide R18n translation helpers' do
    set_locale( 'en' ).locale.code.should == 'en'
    f = TestR18nForm.new
    p = f.param( :msg2 )
    p.title.should == 'Second Message'
    p.form_title.should == 'Another Message'
    p.error_title.to_s.should == '[forms.test_r18n_form.msg2.error_title]'

    set_locale( 'cs' ).locale.code.should == 'cs'
    p.title.should == 'Druhá zpráva'
    p.form_title.should == 'Zpráva'
    p.error_title.should == 'Parametr druhá zpráva'

    f.t.foo.to_s.should == '[foo]'
    f.ft.foo.to_s.should == 'forms.test_r18n_form.[foo]'
    p.t.foo.to_s.should == '[foo]'
    p.ft.foo.to_s.should == 'forms.test_r18n_form.[foo]'
    p.pt.foo.to_s.should == 'forms.test_r18n_form.msg2.[foo]'
  end

end

# EOF #
