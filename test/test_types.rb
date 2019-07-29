# encoding: UTF-8

require_relative 'helper'

require 'form_input/core'
require 'form_input/types'
require 'rack/test'

class TestBasicTypesForm < FormInput
  param :int, INTEGER_ARGS
  param :float, FLOAT_ARGS
  param :bool, BOOL_ARGS
  param :checkbox, CHECKBOX_ARGS
end

class TestJSONTypesForm < FormInput
  param :str
  param :int, INTEGER_ARGS
  param :float, FLOAT_ARGS
  param :bool, BOOL_ARGS
end

class TestAddressTypesForm < FormInput
  param :email, EMAIL_ARGS
  param :zip, ZIP_ARGS
  param :phone, PHONE_ARGS
end

class TestTimeTypesForm < FormInput
  param :time, TIME_ARGS
  param :us_date, US_DATE_ARGS
  param :uk_date, UK_DATE_ARGS
  param :eu_date, EU_DATE_ARGS
  param :hours, HOURS_ARGS
end

class TestPrunedTypesForm < FormInput
  param :str, PRUNED_ARGS
  param :int, INTEGER_ARGS, PRUNED_ARGS
  array :arr, PRUNED_ARGS
  array :int_arr, INTEGER_ARGS, PRUNED_ARGS
  hash :hsh, PRUNED_ARGS
  hash :int_hsh, INTEGER_ARGS, PRUNED_ARGS
end

class Bacon::Context

  def each_timezone
    yield nil
    ( -14 .. 12 ).each{ |x| yield "Etc/GMT%+d" % x }
  end

  def with_timezone( zone )
    saved, ENV[ 'TZ' ] = ENV[ 'TZ' ], zone
    yield
  ensure
    ENV[ 'TZ' ] = saved
  end

  def with_each_timezone( &block )
    each_timezone{ |zone| with_timezone( zone, &block ) }
  end

end

describe FormInput do

  def request( query )
    Rack::Request.new( Rack::MockRequest.env_for( query ) )
  end

  def names( params )
    params.map{ |x| x && x.name }
  end

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

  should 'provide presets for standard parameter types' do
    f = TestBasicTypesForm.new( request( "?int=0123&float=0123.456&bool=true&checkbox=on" ) )
    f.should.be.valid
    f.to_hash.should == { int: 123, float: 123.456, bool: true, checkbox: true }
    f.url_params.should == { int: "123", float: "123.456", bool: "true", checkbox: "true" }
    f.url_query.should == "int=123&float=123.456&bool=true&checkbox=true"

    f = TestBasicTypesForm.new( request( "?bool=false&checkbox=" ) )
    f.should.be.valid
    f.to_hash.should == { bool: false, checkbox: false }
    f.url_params.should == { bool: "false", checkbox: "" }
    f.url_query.should == "bool=false&checkbox="

    f = TestBasicTypesForm.new( request( "?int=a&float=b&bool=c&checkbox=d" ) )
    f.should.be.invalid
    names( f.invalid_params ).should == [ :int, :float ]
    f.to_hash.should == { int: "a", float: "b", bool: false, checkbox: true }
    f.url_params.should == { int: "a", float: "b", bool: "false", checkbox: "true" }
    f.url_query.should == "int=a&float=b&bool=false&checkbox=true"
  end

  should 'provide presets for standard JSON types' do
    f = TestJSONTypesForm.from_data( {} )
    f.should.be.valid
    f.to_data.should == {}

    f = TestJSONTypesForm.from_data( str: "foo", int: "0123", float: "0123.456", bool: "true" )
    f.should.be.valid
    f.to_data.should == { str: 'foo', int: 123, float: 123.456, bool: true }

    f = TestJSONTypesForm.from_data( str: nil, int: 123, float: 123.456, bool: true )
    f.should.be.valid
    f.to_data.should == { str: nil, int: 123, float: 123.456, bool: true }

    f = TestJSONTypesForm.from_data( bool: "false" )
    f.should.be.valid
    f.to_data.should == { bool: false }

    f = TestJSONTypesForm.from_data( bool: false )
    f.should.be.valid
    f.to_data.should == { bool: false }

    f = TestJSONTypesForm.from_data( int: "a", float: "b", bool: "c" )
    f.should.be.invalid
    names( f.invalid_params ).should == [ :int, :float ]
    f.to_data.should == { int: "a", float: "b", bool: false }
  end

  should 'provide presets for address parameter types' do
    f = TestAddressTypesForm.new( request( "?email=me@1.com&zip=12345&phone=123%20456%20789" ) )
    f.should.be.valid
    f.to_hash.should == { email: "me@1.com", zip: "12345", phone: "123 456 789" }
    f.url_params.should == { email: "me@1.com", zip: "12345", phone: "123 456 789" }
    f.url_query.should == "email=me%401.com&zip=12345&phone=123+456+789"

    f = TestAddressTypesForm.new( request( "?email=a&zip=a.b&phone=a" ) )
    f.should.be.invalid
    names( f.invalid_params ).should == [ :email, :zip, :phone ]
    f.to_hash.should == { email: "a", zip: "a.b", phone: "a" }
    f.url_params.should == { email: "a", zip: "a.b", phone: "a" }
    f.url_query.should == "email=a&zip=a.b&phone=a"
  end

  should 'provide presets for time parameter types' do
    f = TestTimeTypesForm.new
    f.param( :time )[ :placeholder ].should == "YYYY-MM-DD HH:MM:SS"
    f.param( :us_date )[ :placeholder ].should == "MM/DD/YYYY"
    f.param( :uk_date )[ :placeholder ].should == "DD/MM/YYYY"
    f.param( :eu_date )[ :placeholder ].should == "D.M.YYYY"
    f.param( :hours )[ :placeholder ].should == "HH:MM"

    with_each_timezone do

      f = TestTimeTypesForm.new( request( "?time=1999-12-31+23:59:48&us_date=1/2/3&uk_date=1/2/3&eu_date=1.2.3&hours=23:59" ) )
      f.should.be.valid
      f.to_hash.should == {
        time: Time.utc( 1999, 12, 31, 23, 59, 48 ),
        us_date: Time.utc( 3, 1, 2 ),
        uk_date: Time.utc( 3, 2, 1 ),
        eu_date: Time.utc( 3, 2, 1 ),
        hours: ( 23 * 60 + 59 ) * 60,
      }
      f.url_params.should == { time: "1999-12-31 23:59:48", us_date: "01/02/0003", uk_date: "01/02/0003", eu_date: "1.2.0003", hours: "23:59" }
      f.url_query.should == "time=1999-12-31+23%3A59%3A48&us_date=01%2F02%2F0003&uk_date=01%2F02%2F0003&eu_date=1.2.0003&hours=23%3A59"

      f = TestTimeTypesForm.new( request( "?time=3-2-1+0:0:0&us_date=12/31/1999&uk_date=31/12/1999&eu_date=31.12.1999&hours=0:0" ) )
      f.should.be.valid
      f.to_hash.should == {
        time: Time.utc( 3, 2, 1, 0, 0, 0 ),
        us_date: Time.utc( 1999, 12, 31 ),
        uk_date: Time.utc( 1999, 12, 31 ),
        eu_date: Time.utc( 1999, 12, 31 ),
        hours: 0,
      }
      f.url_params.should == { time: "0003-02-01 00:00:00", us_date: "12/31/1999", uk_date: "31/12/1999", eu_date: "31.12.1999", hours: "00:00" }
      f.url_query.should == "time=0003-02-01+00%3A00%3A00&us_date=12%2F31%2F1999&uk_date=31%2F12%2F1999&eu_date=31.12.1999&hours=00%3A00"

      f = TestTimeTypesForm.new( request( "?time=1+Feb+3+13:15&us_date=1+Feb+3&uk_date=3-2-1&eu_date=Feb+1st+3&hours=1:2" ) )
      f.should.be.valid
      f.to_hash.should == {
        time: Time.utc( 2003, 2, 1, 13, 15, 0 ),
        us_date: Time.utc( 2003, 2, 1 ),
        uk_date: Time.utc( 2003, 2, 1 ),
        eu_date: Time.utc( 2003, 2, 1 ),
        hours: ( 1 * 60 + 2 ) * 60,
      }
      f.url_params.should == { time: "2003-02-01 13:15:00", us_date: "02/01/2003", uk_date: "01/02/2003", eu_date: "1.2.2003", hours: "01:02" }
      f.url_query.should == "time=2003-02-01+13%3A15%3A00&us_date=02%2F01%2F2003&uk_date=01%2F02%2F2003&eu_date=1.2.2003&hours=01%3A02"

      f = TestTimeTypesForm.new( request( "?time=50+Feb&us_date=foo&uk_date=32+1&eu_date=1+x&hours=25:45" ) )
      f.should.be.invalid
      names( f.invalid_params ).should == [ :time, :us_date, :uk_date, :eu_date, :hours ]
      f.to_hash.should == { time: "50 Feb", us_date: "foo", uk_date: "32 1", eu_date: "1 x", hours: "25:45" }
      f.url_params.should == { time: "50 Feb", us_date: "foo", uk_date: "32 1", eu_date: "1 x", hours: "25:45" }
      f.url_query.should == "time=50+Feb&us_date=foo&uk_date=32+1&eu_date=1+x&hours=25%3A45"

      f = TestTimeTypesForm.new( request( "?time=&us_date=&uk_date=&eu_date=&hours=" ) )
      f.should.be.valid
      f[ :time, :us_date, :uk_date, :eu_date, :hours ].should == [ nil, nil, nil, nil, nil ]
      f.to_hash.should == {}
      f.url_params.should == {}
      f.url_query.should == ""

    end
  end

  describe 'Time parsing helper' do

    should 'raise when string is not parsed entirely' do
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

    should 'correctly ignore % modifiers in time format' do
      for string, format in [ "2000 %- 2", "%Y %%- %-m", "99  3", "%y %_m", "1/12", "%-d/%m", "FEBRUARY", "%^B" ].each_slice( 2 )
        FormInput.parse_time( string, format ).strftime( format ).should == string
      end
    end

    should 'work regardless of the timezone' do
      offsets = []
      with_each_timezone do
        offsets << Time.now.utc_offset
        FormInput.parse_time( "2000-12-01 00:00:00", "%Y-%m-%d %H:%M:%S" ).should == Time.utc( 2000, 12, 1, 0, 0, 0 )
        FormInput.parse_time( "2000-12-01 12:13:14", "%Y-%m-%d %H:%M:%S" ).should == Time.utc( 2000, 12, 1, 12, 13, 14 )
        FormInput.parse_time( "2000-12-01 23:59:59", "%Y-%m-%d %H:%M:%S" ).should == Time.utc( 2000, 12, 1, 23, 59, 59 )

        FormInput.parse_time!( "2000 Dec 1 00:00:00", "%Y-%m-%d %H:%M:%S" ).should == Time.utc( 2000, 12, 1, 0, 0, 0 )
        FormInput.parse_time!( "2000 Dec 1 12:13:14", "%Y-%m-%d %H:%M:%S" ).should == Time.utc( 2000, 12, 1, 12, 13, 14 )
        FormInput.parse_time!( "2000 Dec 1 23:59:59", "%Y-%m-%d %H:%M:%S" ).should == Time.utc( 2000, 12, 1, 23, 59, 59 )
      end
      offsets.uniq.count.should.be >= 24
    end

  end

  should 'provide transformation for pruning empty values from input' do
    c = Class.new( FormInput ).copy( TestPrunedTypesForm, transform: nil )

    f = TestPrunedTypesForm.new( request( "?str=foo&int=1" ) )
    f.to_h.should == { str: "foo", int: 1 }
    f.url_query.should == "str=foo&int=1"
    f = c.new( request( "?str=foo&int=1" ) )
    f.to_h.should == { str: "foo", int: 1 }
    f.url_query.should == "str=foo&int=1"

    f = TestPrunedTypesForm.new( request( "?str=&int=" ) )
    f.to_h.should == {}
    f.url_query.should == ""
    f[ :str, :int ].should == [ nil, nil ]
    f = c.new( request( "?str=&int=" ) )
    f.to_h.should == {}
    f.url_query.should == ""
    f[ :str, :int ].should == [ "", nil ]

    f = TestPrunedTypesForm.new( request( "?arr[]=foo&arr[]=&arr[]=bar&arr[]=&int_arr[]=&int_arr[]=5&int_arr[]=" ) )
    f.to_h.should == { arr: [ "foo", "bar" ], int_arr: [ 5 ] }
    f.url_query.should == "arr[]=foo&arr[]=bar&int_arr[]=5"
    f = c.new( request( "?arr[]=foo&arr[]=&arr[]=bar&arr[]=&int_arr[]=&int_arr[]=5&int_arr[]=" ) )
    f.to_h.should == { arr: [ "foo", "", "bar", "" ], int_arr: [ nil, 5, nil ] }
    f.url_query.should == "arr[]=foo&arr[]=&arr[]=bar&arr[]=&int_arr[]=&int_arr[]=5&int_arr[]="

    f = TestPrunedTypesForm.new( request( "?arr[]=&int_arr[]=" ) )
    f.to_h.should == {}
    f.url_query.should == ""
    f = c.new( request( "?arr[]=&int_arr[]=" ) )
    f.to_h.should == { arr: [ "" ], int_arr: [ nil ] }
    f.url_query.should == "arr[]=&int_arr[]="

    f = TestPrunedTypesForm.new( request( "?hsh[5]=foo&hsh[8]=&hsh[10]=bar&hsh[13]=&int_hsh[3]=&int_hsh[2]=5&int_hsh[1]=" ) )
    f.to_h.should == { hsh: { 5 => "foo", 10 => "bar" }, int_hsh: { 2 => 5 } }
    f.url_query.should == "hsh[5]=foo&hsh[10]=bar&int_hsh[2]=5"
    f = c.new( request( "?hsh[5]=foo&hsh[8]=&hsh[10]=bar&hsh[13]=&int_hsh[3]=&int_hsh[2]=5&int_hsh[1]=" ) )
    f.to_h.should == { hsh: { 5 => "foo", 8 => "", 10 => "bar", 13 => "" }, int_hsh: { 3 => nil, 2 => 5, 1 => nil } }
    f.url_query.should == "hsh[5]=foo&hsh[8]=&hsh[10]=bar&hsh[13]=&int_hsh[3]=&int_hsh[2]=5&int_hsh[1]="

    f = TestPrunedTypesForm.new( request( "?hsh[8]=&int_hsh[11]=" ) )
    f.to_h.should == {}
    f.url_query.should == ""
    f = c.new( request( "?hsh[8]=&int_hsh[11]=" ) )
    f.to_h.should == { hsh: { 8 => "" }, int_hsh: { 11 => nil } }
    f.url_query.should == "hsh[8]=&int_hsh[11]="
  end

end

# EOF #
