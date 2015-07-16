# encoding: UTF-8

require 'form_input/types'

describe FormInput do

  should 'provide helper regular expressions' do
    for s in %w[ me@dot.com me@1.cz me.foo_bar+com%123=098@x.co.uk Me@BAR.INFO ]
      FormInput::SIMPLE_EMAIL_RE.should.match s
    end
    for s in %w[ m @ @. a@ @b m@d a@.b x@y.z q@y..bot f'x@y.com f?x@foo.bar f!z@x.edu ]
      FormInput::SIMPLE_EMAIL_RE.should.not.match s
    end

    for s in [ "X", "M.J.", "John Doe", "Šimon Třešňák", "Šimková-Plívová"]
      FormInput::LATIN_NAMES_RE.should.match s
    end
    for s in %w[ ! @ # $ % ^ & * ( ) , : ; ? = | / \\ { } " ' ` ~ \[ \] ] + [ "Алекс", "गांधी", "宮本 茂"]
      FormInput::LATIN_NAMES_RE.should.not.match s
    end

    for s in [ "0123456789", "+420 602 602 602", "0 (345) 123 123", "905 111-CALL-MAX", "123 123 ext 123"]
      FormInput::PHONE_NUMBER_RE.should.match s
      FormInput::PHONE_NUMBER_RE.should.match s.instance_exec( &FormInput::PHONE_NUMBER_FILTER )
    end
    for s in [ "123/323/569", "123.323.498", "1 - 2"  ]
      FormInput::PHONE_NUMBER_RE.should.not.match s
      FormInput::PHONE_NUMBER_RE.should.match s.instance_exec( &FormInput::PHONE_NUMBER_FILTER )
    end
    for s in [ "abc", "01--2323", "12()3", "12(3", "12)3", "-123", "123-" ]
      FormInput::PHONE_NUMBER_RE.should.not.match s
      FormInput::PHONE_NUMBER_RE.should.not.match s.instance_exec( &FormInput::PHONE_NUMBER_FILTER )
    end

    for s in [ "32 767", "123-1234", "ABC 123", "ABC-ABC", "abc abc" ]
      FormInput::ZIP_CODE_RE.should.match s
    end
    for s in [ "a/b", "1/2", "#23", "1.2", "2+3", "a!", "a--b", "a-", "-a" ]
      FormInput::ZIP_CODE_RE.should.not.match s
    end
  end

  should 'provide Time parsing helper which raises when string is not parsed entirely' do
    for c in ( 0..255 ).map( &:chr )
      FormInput.parse_time( "2000", "%Y" ).year.should == 2000
      FormInput.parse_time( "2000" + c, "%Y" + c ).year.should == 2000

      unless c =~ /\d/
        ->{ FormInput.parse_time( "2000" + c, "%Y" ) }.should.raise ArgumentError
      end
      unless c =~ /\s/
        ->{ FormInput.parse_time( "2000", "%Y" + c ) }.should.raise ArgumentError
      end

      ->{ FormInput.parse_time( "2000", "%y" ) }.should.raise ArgumentError
      ->{ FormInput.parse_time( "2000" + c, "%y" + c ) }.should.raise ArgumentError

      ->{ FormInput.parse_time( "2000" + c, "%y" ) }.should.raise ArgumentError
      ->{ FormInput.parse_time( "2000", "%y" + c ) }.should.raise ArgumentError
    end
  end
    
end

# EOF #
