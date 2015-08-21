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
  param :msg3, plural: true
  param :bool, BOOL_ARGS
end

class TestInflectionForm < FormInput
  param! :name, "Name"
  param! :address, "Address"
  param! :state, "State"
  param! :author, "Author"
  param! :friends, "Friends", plural: true
  param! :chars, "Characters", plural: true
  param! :keywords, "Keywords", plural: true
  param! :notes, "Notes", plural: true
  param :test
end

class TestLocalizedStepsForm < FormInput
  define_steps(
    one: "First",
    two: "Second",
    three: "Third",
    four: nil,
  )
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
    [ 'q like this is not allowed', 'q v tomto tvaru není povolen', q: 'abcd' ],
    [ 'q like this is not valid', 'q není ve správném tvaru', q: '12345' ],
  ]

  after do
    R18n.reset!
  end

  def set_locale( code, found = code )
    result = R18n.set( code, [ "#{__FILE__}/../r18n", FormInput.translations_path ] )
    result.locale.code.should == found
    result
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
    set_locale( 'en' )
    test_translations do |msg, reference|
      msg.should == reference
    end

    set_locale( 'cs' )
    test_translations do |msg, reference, translation|
      msg.should == translation
    end

    set_locale( 'xx' )
    test_translations do |msg, reference|
      msg.should =~ /^{{.*}}$/ unless msg.empty?
      msg.should =~ /^{{.*{{.*}}}}$/ if msg =~ /\d \w/
      msg.gsub( /{{|}}/, '' ).should == reference
    end
  end

  should 'fallback to English error messages for unsupported locales' do
    set_locale( 'zz', 'en' )
    test_translations do |msg, reference|
      msg.should == reference
    end
  end

  should 'automatically support inflection of localized strings' do
    set_locale( 'en' )
    f = TestInflectionForm.new
    f.error_messages.should == [
      "Name is required",
      "Address is required",
      "State is required",
      "Author is required",
      "Friends are required",
      "Characters are required",
      "Keywords are required",
      "Notes are required",
    ]
    set_locale( 'cs' )
    f.validate!
    f.error_messages.should == [
      "Jméno je povinné",
      "Adresa je povinná",
      "Stát je povinný",
      "Autor je povinný",
      "Přátelé jsou povinní",
      "Znaky jsou povinné",
      "Klíčová slova jsou povinná",
      "Poznámky jsou povinné",
    ]
  end

  should 'report invalid inflection strings' do
    set_locale( 'cs' )
    f = TestInflectionForm.new
    p = f.param( :test )
    p.report( :required_scalar ).error.should == 'form_input.errors.required_scalar.[invalid]'
  end

  should 'provide scope name for automatic translations' do
    TestR18nForm.translation_name.should == 'test_r18n_form'
    TestInflectionForm.translation_name.should == 'test_inflection_form'
  end

  should 'automatically translate string options when possible' do
    set_locale( 'cs' )
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

  should 'use default string options for missing translations' do
    set_locale( 'en' )
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
    set_locale( 'en' )
    f = TestR18nForm.new
    p = f.param( :msg2 )
    p.title.should == 'Second Message'
    p.form_title.should == 'Another Message'
    p.error_title.to_s.should == '[forms.test_r18n_form.msg2.error_title]'

    set_locale( 'cs' )
    p.title.should == 'Druhá zpráva'
    p.form_title.should == 'Zpráva'
    p.error_title.should == 'Parametr druhá zpráva'

    f.t.foo.to_s.should == '[foo]'
    p.t.foo.to_s.should == '[foo]'

    f.ft.foo.to_s.should == 'forms.test_r18n_form.[foo]'
    p.ft.foo.to_s.should == 'forms.test_r18n_form.[foo]'
    p.pt.foo.to_s.should == 'forms.test_r18n_form.msg2.[foo]'

    f.ft( :foo ).to_s.should == 'forms.test_r18n_form.[foo]'
    p.ft( :foo ).to_s.should == 'forms.test_r18n_form.[foo]'
    p.pt( :foo ).to_s.should == 'forms.test_r18n_form.msg2.[foo]'

    p = f.param( :msg3 )
    f.ft.texts.test.should == 'Test'
    f.ft[ :texts ].test.should == 'Test'
    f.ft( :texts ).test.should == 'Test'
    p.ft.texts.test.should == 'Test'
    p.ft[ :texts ].test.should == 'Test'
    p.ft( :texts ).test.should == 'Test'
    p.pt.test_msg( 10 ).should == 'Argument 10'
    p.pt[ :test_msg, 10 ].should == 'Argument 10'
    p.pt( :test_msg, 10 ).should == 'Argument 10'
    # Indeed, because without parameter context, the default is singular neuter.
    p.pt.inflected_msg.should == 'Singular'
    p.pt[ :inflected_msg ].should == 'Singular'
    p.pt.inflected_msg( p ).should == 'Plural'
    p.pt[ :inflected_msg, p ].should == 'Plural'
    # This form adds the parameter context automatically.
    p.pt( :inflected_msg ).should == 'Plural'
  end

  should 'automatically localize the boolean helper' do
    R18n.get.should.be.nil
    f = TestR18nForm.new
    p = f.param( :bool )
    p.data.should == [ [ true, 'Yes' ], [ false, 'No' ] ]
    set_locale( 'en' )
    p.data.should == [ [ true, 'Yes' ], [ false, 'No' ] ]
    set_locale( 'cs' )
    p.data.should == [ [ true, 'Ano' ], [ false, 'Ne' ] ]
    p.data.first.last.class.should.equal String
    p.data.last.last.class.should.equal String
  end

  should 'localize the step names' do
    R18n.get.should.be.nil
    f = TestLocalizedStepsForm.new
    f.form_steps.should == { one: "First", two: "Second", three: "Third", four: nil }
    f.step_names.should == { one: "First", two: "Second", three: "Third" }
    f.step_name.should == "First"
    f.step_name( :two ).should == "Second"
    f.step_name( :four ).should.be.nil
    f.step_name( :none ).should.be.nil
    f.step_name.class.should.equal String
    f.step_names[ :one ].class.should.equal String

    set_locale( 'en' )
    f.form_steps.should == { one: "First", two: "Second", three: "Third", four: nil }
    f.step_names.should == { one: "First", two: "Second", three: "Third" }
    f.step_name.should == "First"
    f.step_name( :two ).should == "Second"
    f.step_name( :four ).should.be.nil
    f.step_name( :none ).should.be.nil
    f.step_name.class.should.equal String
    f.step_names[ :one ].class.should.equal String

    set_locale( 'cs' )
    f.form_steps.should == { one: "First", two: "Second", three: "Third", four: nil }
    f.step_names.should == { one: "První", two: "Druhý", three: "Třetí" }
    f.step_name.should == "První"
    f.step_name( :two ).should == "Druhý"
    f.step_name( :four ).should.be.nil
    f.step_name( :none ).should.be.nil
    f.step_name.class.should.equal String
    f.step_names[ :one ].class.should.equal String
  end

end

# EOF #
