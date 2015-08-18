# encoding: UTF-8

require 'form_input/core'
require 'rack/test'

class TestForm < FormInput
  param! :query, :q
  param :email, "Email",
    form_title: "Your email",
    error_title: "email address",
    match: /@/,
    type: :email
  param :age,
    min: 1,
    max: 200,
    filter: ->{ Integer( self, 10 ) rescue self },
    class: Integer,
    tag: :filter
  param :rate,
    inf: 0,
    sup: 1,
    reject: [ /[a-z]/i, /[-+]/ ],
    tags: ->{ [ :filter, :float ] },
    tag: :mix,
    disabled: true
  param :text, 1000,
    min_bytesize: 2,
    max_bytesize: 1999,
    filter: nil
  param :password, "Password",
    min_size: 6,
    max_size: 16,
    match: [ /[A-Z]/, /[a-z]/, /\d/ ],
    msg: 'Password must contain one lowercase and one uppercase letter and one digit',
    type: :password do
      chomp
    end
  array :opts,
    min_count: 2,
    max_count: 3,
    match: /\A[01]\z/,
    check: ->{ report( "Only one option may be set" ) unless value.one?{ |x| x.to_i == 1 } }
  hash :on,
    min_count: 2,
    max_count: 4,
    match: /\A\d\z/,
    type: :hidden,
    test: ->( value ){ report( "%p value is too large" ) if value.to_i > 8 }
end

class TestFormInputApp
  def content( request )
    form = TestForm.new( request )
    if form.valid?
      form.url_query
    else
      form.error_messages.join( ':' )
    end
  end
  def call( env )
    request = Rack::Request.new( env )
    response = Rack::Response.new
    response.write content( request )
    response.finish
  end
end

describe FormInput do

  VALID_PARAMS = [
    [ 'q=2', q: 2 ],
    [ 'q=-', q: "\n-\n" ],
    [ 'q=%2B', q: " + " ],
    [ 'q=a+b', q: " a b " ],
    [ 'q=a+b', q: " \t\r\na \t\r\n b\r\n\t " ],
    [ 'q=1&email=foo%40bar.com', email: 'foo@bar.com' ],
    [ 'q=1&age=12&rate=0.3', age: 12, rate: 0.3 ],
    [ 'q=1&age=1&rate=0.00001', age: 1, rate: '0.00001' ],
    [ 'q=1&age=200&rate=0.99999', age: 200, rate: '0.99999' ],
    [ 'q=1&text=%22%27%3C%3E%26%3B%23%40%25+%09%0D%0A%2B', text: "\"'<>&;#\@% \t\r\n+" ],
    [ 'q=1&text=aa', text: "aa" ],
    [ 'q=1&text=' + 'a' * 1000, text: "a" * 1000 ],
    [ 'q=1', text: nil ],
    [ 'q=1', text: "" ],
    [ 'q=1&text=++', text: "  " ],
    [ 'q=1', email: nil ],
    [ 'q=1', email: "" ],
    [ 'q=1', email: "  " ],
    [ 'q=1&password=Abc123', password: "Abc123" ],
    [ 'q=1&password=Abc123', password: "Abc123\n" ],
    [ 'q=1&password=+Abc123+', password: " Abc123 " ],
    [ 'q=1&password=0123456789abcdeF', password: "0123456789abcdeF" ],
    [ 'q=1', password: nil ],
    [ 'q=1', password: "" ],
    [ 'q=1&password=+aA1+%09', password: " aA1 \t\r\n" ],
    [ 'q=1&password=+aA1+%09', password: " aA1 \t\n" ],
    [ 'q=1&password=+aA1+%09', password: " aA1 \t\r" ],
    [ 'q=1&password=+aA1+%09%0D%0A', password: " aA1 \t\r\n\r\n" ],
    [ 'q=1&password=+aA1+%09%0A', password: " aA1 \t\n\n" ],
    [ 'q=1&password=+aA1+%09%0D', password: " aA1 \t\r\r" ],
    [ 'q=1&opts[]=0&opts[]=1', opts: [ 0, 1 ] ],
    [ 'q=1&opts[]=0&opts[]=1&opts[]=0', opts: [ 0, 1, 0 ] ],
    [ 'q=1&on[0]=1&on[2]=8', on: { 0 => 1, 2 => 8 } ],
  ]

  INVALID_PARAMS = [
    [ 'q is required', q: nil ],
    [ 'q is required', q: "" ],
    [ 'q is required', q: "   \t\r\n " ],
    [ 'q is not a string', q: [ 10 ] ],
    [ 'q is not a string', q: { "x" => "y" } ],
    [ 'q must use valid encoding', q: 255.chr.force_encoding( 'UTF-8' ) ],
    [ 'q is required', q: "\u{0000}" ],  # Because strip strips \0 as well.
    [ 'q may not contain invalid characters', q: "a\u{0000}b" ],
    [ 'q may not contain invalid characters', q: "\u{0001}" ],
    [ 'q may not contain invalid characters', q: "\u{2029}" ],
    [ 'email address like this is not valid', email: 'abc' ],
    [ 'email address must have at most 255 characters', email: 'a@' + 'a' * 254 ],
    [ 'email address must have at most 255 bytes', email: 'á@' + 'a' * 253 ],
    [ 'age like this is not valid', age: 0.9 ],
    [ 'age must be at least 1', age: 0 ],
    [ 'age must be at most 200', age: 201 ],
    [ 'rate like this is not allowed', rate: '0.9e10' ],
    [ 'rate like this is not allowed', rate: '-10' ],
    [ 'rate must be greater than 0', rate: 0 ],
    [ 'rate must be less than 1', rate: 1 ],
    [ 'text must have at least 2 bytes', text: " " ],
    [ 'text must have at least 2 bytes', text: "a" ],
    [ 'text must have at most 1000 characters', text: "a" * 1001 ],
    [ 'text must have at most 1999 bytes', text: "á" * 1000 ],
    [ 'Password must contain one lowercase and one uppercase letter and one digit', password: "abc123" ],
    [ 'Password must contain one lowercase and one uppercase letter and one digit', password: "ABC123" ],
    [ 'Password must contain one lowercase and one uppercase letter and one digit', password: "abcABC" ],
    [ 'Password must have at least 6 characters', password: "   \t\r\n" ],
    [ 'Password must have at least 6 characters', password: "Abc12" ],
    [ 'Password must have at most 16 characters', password: "0123456789abcdefG" ],
    [ 'opts are not an array', opts: "" ],
    [ 'opts are not an array', opts: " " ],
    [ 'opts are not an array', opts: "x" ],
    [ 'opts are not an array', opts: { 1 => 2 } ],
    [ 'opts contain invalid value', opts: [ 1, { 0 => 1 } ] ],
    [ 'opts must have at least 2 elements', opts: [ 0 ] ],
    [ 'opts must have at most 3 elements', opts: [ 0, 1, 0, 0 ] ],
    [ 'Only one option may be set', opts: [ 0, 1, 1 ] ],
    [ 'opts like this is not valid', opts: [ 1, 2, 3 ] ],
    [ 'on are not a hash', on: "" ],
    [ 'on are not a hash', on: " " ],
    [ 'on are not a hash', on: "x" ],
    [ 'on are not a hash', on: [ 2 ] ],
    [ 'on contain invalid key', on: { "k" => 1, 2 => 3 } ],
    [ 'on contain invalid key', on: { "0b0" => 1, 2 => 3 } ],
    [ 'on contain invalid key', on: { "0x0" => 1, 2 => 3 } ],
    [ 'on contain invalid key', on: { "foo" => 1, "bar" => 3 } ],
    [ 'on contain too small key', on: { -1 => 1, 2 => 3 } ],
    [ 'on contain too large key', on: { ( 1 << 64 ) => 1, 2 => 3 } ],
    [ 'on contain invalid value', on: { 0 => 1, 2 => { 3 => 4 } } ],
    [ 'on contain invalid value', on: { 0 => 1, 2 => [ 3 ] } ],
    [ 'on must have at least 2 elements', on: { 1 => 1 } ],
    [ 'on must have at most 4 elements', on: { 1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 5 } ],
    [ 'on like this is not valid', on: { 0 => 1, 2 => 2000 } ],
    [ 'on like this is not valid', on: { 0 => 1, 2 => "z" } ],
    [ 'on value is too large', on: { 0 => 9, 2 => 9 } ],
  ]
  
  extend Rack::Test::Methods

  def app
    TestFormInputApp.new
  end

  def request( query )
    Rack::Request.new( Rack::MockRequest.env_for( query ) )
  end

  def names( params )
    params.map{ |x| x && x.name }
  end
  
  should 'provide request parameters' do
    for result, params in VALID_PARAMS
      post( '/form?q=1', params ).body.should == result
    end
  end
  
  should 'detect invalid parameters' do
    for result, params in INVALID_PARAMS
      post( '/form?q=1', params ).body.should == result
    end
  end
  
  should 'complain about incorrect parameter definition' do
    ->{ TestForm.param :x, "test", "test" }.should.raise( ArgumentError )
    ->{ TestForm.param :x, { type: :email }, :extra }.should.raise( ArgumentError )
    ->{ TestForm.param :x, { type: :email }, nil }.should.raise( ArgumentError )

    ->{ TestForm.param :query }.should.raise( ArgumentError )
    ->{ TestForm.array! :opts }.should.raise( ArgumentError )

    ->{ TestForm.param :params }.should.raise( ArgumentError )
    ->{ TestForm.param :errors }.should.raise( ArgumentError )

    ->{ TestForm.copy nil }.should.raise( ArgumentError )
    ->{ TestForm.copy :foo }.should.raise( ArgumentError )
    ->{ TestForm.copy Object }.should.raise( ArgumentError )
    ->{ TestForm.copy TestForm }.should.raise( ArgumentError )
    ->{ TestForm.copy TestForm[ :query ] }.should.raise( ArgumentError )
  end
  
  should 'be cloned and copied properly' do
    f = TestForm.new
    f.report( :password, "error" )
    f.errors_for( :password ).should == [ "error" ]
    f.errors_for( :text ).should == []
    c = f.clone
    c.should.not.equal f
    d = f.dup
    d.should.not.equal f
    c.errors_for( :password ).should == [ "error" ]
    c.errors_for( :text ).should == []
    d.errors_for( :password ).should == []
    d.errors_for( :text ).should == []
    f.report( :password, "orig" )
    c.report( :password, "clone" )
    d.report( :password, "copy" )
    f.report( :text, "Orig" )
    c.report( :text, "Clone" )
    d.report( :text, "Copy" )
    f.errors_for( :password ).should == [ "error", "orig" ]
    c.errors_for( :password ).should == [ "error", "clone" ]
    d.errors_for( :password ).should == [ "copy" ]
    f.errors_for( :text ).should == [ "Orig" ]
    c.errors_for( :text ).should == [ "Clone" ]
    d.errors_for( :text ).should == [ "Copy" ]
  end
  
  should 'be frozen properly' do
    f = TestForm.new
    f.should.not.be.frozen
    f.freeze
    f.should.be.frozen
    f.should.be.invalid
    f.param( :query ).should.be.invalid
    f.query.should.be.nil

    ->{ f.query = "x" }.should.raise( RuntimeError )
    ->{ f[ :query ] = "y" }.should.raise( RuntimeError )
    ->{ f.set( query: "z" ) }.should.raise( RuntimeError )
    ->{ f.clear }.should.raise( RuntimeError )
    ->{ f.clear( :query ) }.should.raise( RuntimeError )
    ->{ f.report( :query, "error" ) }.should.raise( RuntimeError )
    ->{ f.validate! }.should.raise( RuntimeError )
    ->{ f.validate }.should.not.raise
    ->{ f.validate? }.should.not.raise

     f.clone.should.be.frozen
     f.clone.should.be.invalid
     
    ->{ f.clone.query = "x" }.should.raise( RuntimeError )
    ->{ f.clone[ :query ] = "y" }.should.raise( RuntimeError )
    ->{ f.clone.set( query: "z" ) }.should.raise( RuntimeError )
    ->{ f.clone.clear }.should.raise( RuntimeError )
    ->{ f.clone.clear( :query ) }.should.raise( RuntimeError )
    ->{ f.clone.report( :query, "error" ) }.should.raise( RuntimeError )
    ->{ f.clone.validate! }.should.raise( RuntimeError )
    ->{ f.clone.validate }.should.not.raise
    ->{ f.clone.validate? }.should.not.raise

    f.dup.should.not.be.frozen
    f.dup.should.be.invalid
    
    ->{ f.dup.query = "x" }.should.not.raise
    ->{ f.dup[ :query ] = "y" }.should.not.raise
    ->{ f.dup.set( query: "z" ) }.should.not.raise
    ->{ f.dup.clear }.should.not.raise
    ->{ f.dup.clear( :query ) }.should.not.raise
    ->{ f.dup.report( :query, "error" ) }.should.not.raise
    ->{ f.dup.validate! }.should.not.raise
    ->{ f.dup.validate }.should.not.raise
    ->{ f.dup.validate? }.should.not.raise

    f.query.should.be.nil
  end
  
  should 'support form inheritance' do
    c = Class.new( TestForm ).param :extra
    names( c.new.params ).should == [ :query, :email, :age, :rate, :text, :password, :opts, :on, :extra ]
  end
  
  should 'support parameter copying' do
    c = Class.new( FormInput )
    c.param :first
    c.copy TestForm
    c.param :last
    names( c.new.params ).should == [ :first, :query, :email, :age, :rate, :text, :password, :opts, :on, :last ]

    c = Class.new( FormInput )
    c.param :first
    c.copy TestForm[ :email ]
    c.param :last
    names( c.new.params ).should == [ :first, :email, :last ]

    c = Class.new( FormInput )
    c.param :first
    c.copy TestForm[ :password, :age ]
    c.param :last
    names( c.new.params ).should == [ :first, :password, :age, :last ]
  end
  
  should 'allow changing options when copying parameters' do
    c = Class.new( FormInput )
    c.copy TestForm[ :query ]
    c[ :query ].should.be.required

    c = Class.new( FormInput )
    c.copy TestForm[ :query ], required: false
    c[ :query ].should.not.be.required

    c = Class.new( FormInput )
    c.copy TestForm, required: false
    c[ :query ].should.not.be.required

    c = Class.new( FormInput )
    c.copy TestForm[ :query ], name: nil, code: nil, title: nil
    p = c[ :query ]
    p.name.should == :query
    p.code.should == :q
    p.title.should == nil

    c = Class.new( FormInput )
    c.copy TestForm[ :password ], name: nil, code: nil, title: nil
    p = c[ :password ]
    p.name.should == :password
    p.code.should == :password
    p.title.should == nil

    c = Class.new( FormInput )
    c.copy TestForm[ :email ], name: :foo, code: :bar, title: "FooBar"
    p = c[ :foo ]
    p.name.should == :foo
    p.code.should == :bar
    p.title.should == "FooBar"
  end
  
  should 'support dynamic options' do
    c = Class.new( FormInput )
    c.class_eval "def limit ; 5 ; end"
    c.param :s, max_size: ->{ form.limit }
    c.array :a, max_count: ->{ form.limit }
    
    ->{ c[ :s ][ :max_size ] }.should.raise NoMethodError
    ->{ c[ :a ][ :max_count ] }.should.raise NoMethodError
    
    f = c.new( s: "123456" )
    f.param( :s )[ :max_size ].should == 5
    f.param( :a )[ :max_count ].should == 5
    f.error_messages.should == [ "s must have at most 5 characters" ]
  end
  
  should 'convert to/from internal value format' do
    c = Class.new( FormInput )
    c.param :str
    c.param :int, filter: ->{ to_i }, class: Integer
    c.param :int2, filter: ->{ Integer( self, 10 ) rescue self }, class: Integer,
      check: ->{ report( "%p must be odd" ) unless value.odd? }
    c.param :float, filter: ->{ to_f }, class: Float
    c.param :float2, filter: ->{ Float( self ) rescue self }, class: Float
    c.param :date, filter: ->{ Date.parse( self ) rescue self }, format: ->{ strftime( '%m/%d/%Y' ) }, class: Date
    c.param :time, filter: ->{ Time.parse( self ) rescue self }, format: ->{ strftime( '%Y-%m-%d %H:%M:%S' ) }, class: Time
    c.param :bool, filter: ->{ self == 'true' unless empty? }, class: [ TrueClass, FalseClass ]
    c.param :str2, filter: ->{ downcase.reverse }, format: ->{ reverse.upcase rescue self }
    
    f = c.new( request( "?str=1.5&int=1.5&float=1.5&date=2011-12-31&time=31.12.2000+10:24:05&bool=true&str2=Abc" ) )
    f.should.be.valid
    f.to_h.should == f.to_hash
    f.to_hash.should == {
      str: "1.5",
      int: 1,
      float: 1.5,
      date: Date.new( 2011, 12, 31 ),
      time: Time.new( 2000, 12, 31, 10, 24, 05 ),
      bool: true,
      str2: "cba",
    }
    f.url_params.should == {
      str: "1.5",
      int: "1",
      float: "1.5",
      date: "12/31/2011",
      time: "2000-12-31 10:24:05",
      bool: "true",
      str2: "ABC",
    }
    f.url_query.should == "str=1.5&int=1&float=1.5&date=12%2F31%2F2011&time=2000-12-31+10%3A24%3A05&bool=true&str2=ABC"

    f = c.new( request( "?str=a&int=b&float=c&date=d&time=e&bool=f" ) )
    f.should.be.invalid
    names( f.invalid_params ).should == [ :date, :time ]
    f.error_messages.should == [ "date like this is not valid", "time like this is not valid" ]
    f.to_h.should == f.to_hash
    f.to_hash.should == {
      str: "a",
      int: 0,
      float: 0,
      date: "d",
      time: "e",
      bool: false,
    }
    f.url_params.should == {
      str: "a",
      int: "0",
      float: "0.0",
      date: "d",
      time: "e",
      bool: "false",
    }
    f.url_query.should == "str=a&int=0&float=0.0&date=d&time=e&bool=false"

    f = c.new( request( "?int=1&int2=1&float=1.5&float2=1.5" ) )
    f.should.be.valid
    f.to_hash.should == { int: 1, int2: 1, float: 1.5, float2: 1.5 }
    f.url_params.should == { int: "1", int2: "1", float: "1.5", float2: "1.5" }
    f.url_query.should == "int=1&int2=1&float=1.5&float2=1.5"

    f = c.new( request( "?int=1&int2=1.5&float=foo&float2=foo" ) )
    f.should.be.invalid
    names( f.invalid_params ).should == [ :int2, :float2 ]
    f.error_messages.should == [ "int2 like this is not valid", "float2 like this is not valid" ]
    f.to_hash.should == { int: 1, int2: "1.5", float: 0, float2: "foo" }
    f.url_params.should == { int: "1", int2: "1.5", float: "0.0", float2: "foo" }
    f.url_query.should == "int=1&int2=1.5&float=0.0&float2=foo"

    f = c.new( request( "?int=0x0a&int2=0x0a" ) )
    f.should.be.invalid
    names( f.invalid_params ).should == [ :int2 ]
    f.error_messages.should == [ "int2 like this is not valid" ]
    f.to_hash.should == { int: 0, int2: "0x0a" }
    f.url_params.should == { int: "0", int2: "0x0a" }
    f.url_query.should == "int=0&int2=0x0a"

    f = c.new( request( "?int2=2" ) )
    f.should.be.invalid
    names( f.invalid_params ).should == [ :int2 ]
    f.error_messages.should == [ "int2 must be odd" ]
    f.to_hash.should == { int2: 2 }
    f.url_params.should == { int2: "2" }
    f.url_query.should == "int2=2"
    
    p = c[ :int ]
    p.format_value( nil ).should == ""
    p.format_value( 10 ).should == "10"
    p.format_value( "foo" ).should == "foo"

    p = c[ :float ]
    p.format_value( nil ).should == ""
    p.format_value( 10 ).should == "10"
    p.format_value( 10.0 ).should == "10.0"
    p.format_value( "foo" ).should == "foo"

    p = c[ :date ]
    p.format_value( nil ).should == ""
    p.format_value( Time.at( 123456789 ) ).should == "11/29/1973"
    p.format_value( "foo" ).should == "foo"

    p = c[ :time ]
    p.format_value( nil ).should == ""
    p.format_value( Time.at( 123456789 ) ).should == "1973-11-29 21:33:09"
    p.format_value( "foo" ).should == "foo"

    p = c[ :bool ]
    p.format_value( nil ).should == ""
    p.format_value( true ).should == "true"
    p.format_value( false ).should == "false"
    p.format_value( "foo" ).should == "foo"

    p = c[ :str ]
    p.format_value( nil ).should == ""
    p.format_value( true ).should == "true"
    p.format_value( false ).should == "false"
    p.format_value( 10 ).should == "10"
    p.format_value( 10.0 ).should == "10.0"
    p.format_value( "abc" ).should == "abc"

    p = c[ :str2 ]
    p.format_value( nil ).should == ""
    p.format_value( true ).should == "true"
    p.format_value( false ).should == "false"
    p.format_value( 10 ).should == "10"
    p.format_value( 10.0 ).should == "10.0"
    p.format_value( "abc" ).should == "CBA"
  end
  
  should 'support input transformation' do
    c = Class.new( FormInput )
    c.array :a
    
    f = c.new( request( "?a[]=abc&a[]=&a[]=123&a[]=" ) )
    f.a.should == [ "abc", "", "123", "" ]
  
    c = Class.new( FormInput )
    c.array :a, filter: ->{ reverse }, transform: ->{ reject{ |x| x.empty? } }
    
    f = c.new( request( "?a[]=abc&a[]=&a[]=123&a[]=" ) )
    f.a.should == [ "cba", "321" ]
  
    f = c.new( a: [ "abc", "", "123" ] )
    f.a.should == [ "abc", "", "123" ]
  end
  
  should 'support string hash keys when allowed' do
    c = Class.new( FormInput )
    c.hash :h
    
    f = c.new( request( "?h[0]=a&h[1]=b&h[2]=c" ) )
    f.should.be.valid
    f.h.should == { 0 => 'a', 1 => 'b', 2 => 'c' }
    f.url_query.should == "h[0]=a&h[1]=b&h[2]=c"
    
    f = c.new( request( "?h[a]=a&h[b]=b&h[c]=c" ) )
    f.should.be.invalid
    f.error_messages.should == [ "h contain invalid key" ]
    f.h.should == { 'a' => 'a', 'b' => 'b', 'c' => 'c' }
    f.url_query.should == "h[a]=a&h[b]=b&h[c]=c"

    c = Class.new( FormInput )
    c.hash :h, match_key: /\A\d+\z/
    
    f = c.new( request( "?h[0]=a&h[1]=b&h[2]=c" ) )
    f.should.be.valid
    f.h.should == { 0 => 'a', 1 => 'b', 2 => 'c' }
    f.url_query.should == "h[0]=a&h[1]=b&h[2]=c"
    
    f = c.new( request( "?h[a]=a&h[b]=b&h[c]=c" ) )
    f.should.be.invalid
    f.error_messages.should == [ "h contain invalid key" ]
    f.h.should == { 'a' => 'a', 'b' => 'b', 'c' => 'c' }
    f.url_query.should == "h[a]=a&h[b]=b&h[c]=c"
  
    c = Class.new( FormInput )
    c.hash :h, match_key: /\A[a-z]\z/
    
    f = c.new( request( "?h[0]=a&h[1]=b&h[2]=c" ) )
    f.should.be.invalid
    f.error_messages.should == [ "h contain invalid key" ]
    f.h.should == { 0 => 'a', 1 => 'b', 2 => 'c' }
    f.url_query.should == "h[0]=a&h[1]=b&h[2]=c"
    
    f = c.new( request( "?h[a]=a&h[b]=b&h[c]=c" ) )
    f.should.be.valid
    f.h.should == { 'a' => 'a', 'b' => 'b', 'c' => 'c' }
    f.url_query.should == "h[a]=a&h[b]=b&h[c]=c"

    c = Class.new( FormInput )
    c.hash :h, match_key: ->{ [ /\A[a-z]+\z/i, /^[A-Z]/, /[A-Z]$/ ] }
    
    f = c.new( request( "?h[A]=a&h[Bar]=b&h[baZ]=c" ) )
    f.should.be.invalid
    f.error_messages.should == [ "h contain invalid key" ]
    f.h.should == { 'A' => 'a', 'Bar' => 'b', 'baZ' => 'c' }
    f.url_query.should == "h[A]=a&h[Bar]=b&h[baZ]=c"
    
    f = c.new( request( "?h[A]=a&h[BAR]=b&h[BaZ]=c" ) )
    f.should.be.valid
    f.h.should == { 'A' => 'a', 'BAR' => 'b', 'BaZ' => 'c' }
    f.url_query.should == "h[A]=a&h[BAR]=b&h[BaZ]=c"
  end
  
  should 'support select parameters' do
    c = Class.new( FormInput )
    c.param :single, data: ->{ 2.times.map{ |i| [ i, ( 65 + i ).chr ] } }, class: Integer do to_i end
    c.array :multi, data: ->{ 4.times.map{ |i| [ i, ( 65 + i ).chr ] } }, class: Integer do to_i end
    c.param :x, filter: ->{ to_i }, class: Integer

    f = c.new( single: 1, multi: [ 1, 3 ], x: 5 )
    f.should.be.valid
    f.to_hash.should == { single: 1, multi: [ 1, 3 ], x: 5 }
    f.url_params.should == { single: "1", multi: [ "1", "3" ], x: "5" }
    f.url_query.should == "single=1&multi[]=1&multi[]=3&x=5"
    
    p = f.param( :single )
    p.data.should == [ [ 0, "A" ], [ 1, "B" ] ]
    p.code.should == :single
    p.form_name.should == "single"
    p.form_value.should == "1"
    p.selected?( nil ).should.be.false
    p.selected?( 0 ).should.be.false
    p.selected?( 1 ).should.be.true
    p.selected?( 2 ).should.be.false

    p = f.param( :multi )
    p.data.should == [ [ 0, "A" ], [ 1, "B" ], [ 2, "C" ], [ 3, "D" ] ]
    p.code.should == :multi
    p.form_name.should == "multi[]"
    p.form_value.should == [ "1", "3" ]
    p.selected?( nil ).should.be.false
    p.selected?( 0 ).should.be.false
    p.selected?( 1 ).should.be.true
    p.selected?( 2 ).should.be.false
    p.selected?( 3 ).should.be.true

    p = f.param( :x )
    p.data.should == []
    p.code.should == :x
    p.form_name.should == "x"
    p.form_value.should == "5"

    f = c.new( request( "?single=0&multi[]=0&multi[]=2&x=3" ) ) ;
    f.should.be.valid
    f.to_hash.should == { single: 0, multi: [ 0, 2 ], x: 3 }
    f.url_params.should == { single: "0", multi: [ "0", "2" ], x: "3" }
    f.url_query.should == "single=0&multi[]=0&multi[]=2&x=3"
    
    f = c.new( request( "?single=5&multi[]=5" ) ) ;
    f.should.be.valid
    f.to_hash.should == { single: 5, multi: [ 5 ] }
    f.url_params.should == { single: "5", multi: [ "5" ] }
    f.url_query.should == "single=5&multi[]=5"
    
    f = c.new( request( "" ) ) ;
    f.should.be.valid
    f.to_hash.should == {}
    f.url_params.should == {}
    f.url_query.should == ""
  end
  
  should 'classify parameters' do
    f = TestForm.new( query: "x", text: "abc", password: nil, email: " " )
    names( f.params ).should == [ :query, :email, :age, :rate, :text, :password, :opts, :on ]
    names( f.params ).should == f.params_names

    names( f.named_params ).should == []
    names( f.named_params( :query ) ).should == [ :query ]
    names( f.named_params( :text, :email ) ).should == [ :text, :email ]
    names( f.named_params( :age, :age ) ).should == [ :age, :age ]

    names( f.correct_params ).should == [ :query, :email, :age, :rate, :text, :password, :opts, :on ]
    names( f.incorrect_params ).should == []

    names( f.filled_params ).should == [ :query, :email, :text ]
    names( f.empty_params ).should == [ :age, :rate, :password, :opts, :on ]
    names( f.blank_params ).should == [ :email, :age, :rate, :password, :opts, :on ]

    names( f.tagged_params ).should == [ :age, :rate ]
    names( f.untagged_params ).should == [ :query, :email, :text, :password, :opts, :on ]

    names( f.tagged_params( :filter ) ).should == [ :age, :rate ]
    names( f.untagged_params( :filter ) ).should == [ :query, :email, :text, :password, :opts, :on ]

    names( f.tagged_params( :float ) ).should == [ :rate ]
    names( f.untagged_params( :float ) ).should == [ :query, :email, :age, :text, :password, :opts, :on ]

    names( f.tagged_params( :filter, :float ) ).should == [ :age, :rate ]
    names( f.untagged_params( :filter, :float ) ).should == [ :query, :email, :text, :password, :opts, :on ]

    names( f.tagged_params( :foo ) ).should == []
    names( f.untagged_params( :foo ) ).should == [ :query, :email, :age, :rate, :text, :password, :opts, :on ]

    names( f.tagged_params( :float, :foo ) ).should == [ :rate ]
    names( f.untagged_params( :float, :foo ) ).should == [ :query, :email, :age, :text, :password, :opts, :on ]

    names( f.tagged_params( [] ) ).should == []
    names( f.untagged_params( [] ) ).should == [ :query, :email, :age, :rate, :text, :password, :opts, :on ]

    names( f.tagged_params( [ :filter ] ) ).should == [ :age, :rate ]
    names( f.untagged_params( [ :filter ] ) ).should == [ :query, :email, :text, :password, :opts, :on ]

    names( f.tagged_params( [ :float ] ) ).should == [ :rate ]
    names( f.untagged_params( [ :float ] ) ).should == [ :query, :email, :age, :text, :password, :opts, :on ]

    names( f.tagged_params( [ :filter, :float ] ) ).should == [ :age, :rate ]
    names( f.untagged_params( [ :filter, :float ] ) ).should == [ :query, :email, :text, :password, :opts, :on ]

    names( f.tagged_params( [ :foo ] ) ).should == []
    names( f.untagged_params( [ :foo ] ) ).should == [ :query, :email, :age, :rate, :text, :password, :opts, :on ]

    names( f.tagged_params( [ :float, :foo ] ) ).should == [ :rate ]
    names( f.untagged_params( [ :float, :foo ] ) ).should == [ :query, :email, :age, :text, :password, :opts, :on ]

    names( f.titled_params ).should == [ :email, :password ]
    names( f.untitled_params ).should == [ :query, :age, :rate, :text, :opts, :on ]

    names( f.required_params ).should == [ :query ]
    names( f.optional_params ).should == [ :email, :age, :rate, :text, :password, :opts, :on ]

    names( f.disabled_params ).should == [ :rate ]
    names( f.enabled_params ).should == [ :query, :email, :age, :text, :password, :opts, :on ]

    names( f.hidden_params ).should == [ :on ]
    names( f.ignored_params ).should == []
    names( f.visible_params ).should == [ :query, :email, :age, :rate, :text, :password, :opts ]

    names( f.array_params ).should == [ :opts ]
    names( f.hash_params ).should == [ :on ]
    names( f.scalar_params ).should == [ :query, :email, :age, :rate, :text, :password ]

    names( f.invalid_params ).should == [ :email ]
    names( f.valid_params ).should == [ :query, :age, :rate, :text, :password, :opts, :on ]
  end
  
  should 'expose details via parameters' do
    f = TestForm.new( query: "x", text: "abc", :email => " " )
    
    p = f.param( :query )
    p.form.should == f
    p.name.should == :query
    p.code.should == :q
    p.type.should == :text
    p.title.should == nil
    p.form_title.should == "q"
    p.error_title.should == "q"
    p.opts.should == { required: true, filter: FormInput::DEFAULT_FILTER, max_size: 255, max_bytesize: 255 }
    p[ :form_title ].should == nil
    p[ :max_size ].should == 255
    p.value.should == "x"
    p.form_value.should == "x"
    p.should.be.correct
    p.should.not.be.incorrect
    p.should.not.be.blank
    p.should.not.be.empty
    p.should.be.filled
    p.should.not.be.titled
    p.should.be.untitled
    p.should.be.valid
    p.should.not.be.invalid
    p.should.be.required
    p.should.not.be.optional
    p.should.not.be.disabled
    p.should.be.enabled
    p.should.not.be.hidden
    p.should.not.be.ignored
    p.should.be.visible
    p.should.not.be.array
    p.should.not.be.hash
    p.should.be.scalar
    p.should.not.be.tagged
    p.should.be.untagged
    p.errors.should == []
    p.error.should == nil
    p.tags.should == []

    p = f.param( :email )
    p.form.should == f
    p.name.should == :email
    p.code.should == :email
    p.type.should == :email
    p.title.should == "Email"
    p.form_title.should == "Your email"
    p.error_title.should == "email address"
    p.value.should == " "
    p.form_value.should == " "
    p.should.be.correct
    p.should.not.be.incorrect
    p.should.be.blank
    p.should.not.be.empty
    p.should.be.filled
    p.should.be.titled
    p.should.not.be.untitled
    p.should.not.be.valid
    p.should.be.invalid
    p.should.not.be.required
    p.should.be.optional
    p.should.not.be.disabled
    p.should.be.enabled
    p.should.not.be.hidden
    p.should.not.be.ignored
    p.should.be.visible
    p.should.not.be.array
    p.should.not.be.hash
    p.should.be.scalar
    p.should.not.be.tagged
    p.should.be.untagged
    p.errors.should == [ "email address like this is not valid" ]
    p.error.should == "email address like this is not valid"
    p.tags.should == []
    
    p = f.param( :rate )
    p.value.should == nil
    p.form_value.should == ""
    p.should.be.blank
    p.should.be.empty
    p.should.not.be.filled
    p.should.be.disabled
    p.should.not.be.enabled
    p[ :tag ].should == :mix
    p[ :tags ].should == [ :filter, :float ]
    p.tags.should == [ :mix, :filter, :float ]
    p.should.be.tagged
    p.should.not.be.untagged
    p.should.be.tagged( :filter )
    p.should.not.be.untagged( :filter )
    p.should.be.tagged( :foo, :float )
    p.should.not.be.untagged( :foo, :float )
    p.should.not.be.tagged( :foo )
    p.should.be.untagged( :foo )
    p.should.not.be.tagged( [] )
    p.should.be.untagged( [] )
    p.should.be.tagged( [ :filter ] )
    p.should.not.be.untagged( [ :filter ] )
    p.should.be.tagged( [ :foo, :float ] )
    p.should.not.be.untagged( [ :foo, :float ] )
    p.should.not.be.tagged( [ :foo ] )
    p.should.be.untagged( [ :foo ] )
    
    p = f.param( :opts )
    p.value.should == nil
    p.form_value.should == []
    p.should.be.blank
    p.should.be.empty
    p.should.not.be.filled
    p.should.be.array
    p.should.not.be.hash
    p.should.not.be.scalar

    p = f.param( :on )
    p.opts.values_at( :min_key, :max_key ).should == [ 0, 18446744073709551615 ]
    p.value.should == nil
    p.form_value.should == {}
    p.should.be.blank
    p.should.be.empty
    p.should.not.be.filled
    p.should.not.be.array
    p.should.be.hash
    p.should.not.be.scalar
    p.type.should == :hidden
    p.should.be.hidden
    p.should.not.be.ignored
    p.should.not.be.visible
  end
  
  should 'support both new and derived forms' do
    f = TestForm.new
    f.should.be.empty
    f.url_query.should == ""
    
    f = TestForm.new( request( "" ) )
    f.should.be.empty
    f.url_query.should == ""
    
    f = TestForm.new( request( "?q=10" ) )
    f.should.not.be.empty
    f.url_query.should == "q=10"
    
    f = TestForm.new( query: "x" )
    f.should.not.be.empty
    f.url_query.should == "q=x"
    
    f.set( email: "a@b", text: "foo" )
    f.should.not.be.empty
    f.url_query.should == "q=x&email=a%40b&text=foo"

    f.except( :email ).url_query.should == "q=x&text=foo"
    f.except( :email, :query ).url_query.should == "text=foo"
    f.except().url_query.should == "q=x&email=a%40b&text=foo"
    f.except( [ :email ] ).url_query.should == "q=x&text=foo"
    f.except( [ :email, :query ] ).url_query.should == "text=foo"
    f.except( [] ).url_query.should == "q=x&email=a%40b&text=foo"

    f.only( :email ).url_query.should == "email=a%40b"
    f.only( :email, :query ).url_query.should == "q=x&email=a%40b"
    f.only().url_query.should == ""
    f.only( [ :email ] ).url_query.should == "email=a%40b"
    f.only( [ :email, :query ] ).url_query.should == "q=x&email=a%40b"
    f.only( [] ).url_query.should == ""

    f.clear( :text )
    f.should.not.be.empty
    f.url_query.should == "q=x&email=a%40b"
    f.clear( f.required_params )
    f.should.not.be.empty
    f.url_query.should == "email=a%40b"
    f.clear
    f.should.be.empty
    f.url_query.should == ""

    f = TestForm.new( { age: 2, query: "x" }, { rate: 1, query: "y" } )
    f.should.not.be.empty
    f.url_query.should == "q=y&age=2&rate=1"
    
    f = TestForm.new( request( "?q=10&age=3" ), query: "y", rate: 0 )
    f.should.not.be.empty
    f.url_query.should == "q=y&age=3&rate=0"
    
    f = TestForm.new( { query: "x", age: 5 }, request( "?rate=1&q=10" ) )
    f.should.not.be.empty
    f.url_query.should == "q=10&age=5&rate=1"
  end
  
  should 'provide direct access to values' do
    f = TestForm.new( email: "a@b", text: "foo" )

    f.email.should == "a@b"
    f.email = "x@y"
    f.email.should == "x@y"

    f[ :text ].should == "foo"
    f[ :text ] = "bar"
    f[ :text ].should == "bar"

    f[ :query, :text ].should == [ nil, "bar" ]
    f[ :text, :email ].should == [ "bar", "x@y" ]
  end
    
  should 'guard against typos in parameter names' do
    f = TestForm.new

    f.param( :typo ).should == nil
    f.named_params( :typo ).should == [ nil ]
    f.named_params( :typo, :missing ).should == [ nil, nil ]

    ->{ f.set( typo: 10 ) }.should.raise( NoMethodError )
    ->{ f.clear( :typo ) }.should.raise( ArgumentError )
    ->{ f.except( :typo ) }.should.raise( ArgumentError )
    ->{ f.except( [ :typo ] ) }.should.raise( ArgumentError )
    ->{ f.only( :typo ) }.should.raise( ArgumentError )
    ->{ f.only( [ :typo ] ) }.should.raise( ArgumentError )
    
    ->{ f.typo }.should.raise( NoMethodError )
    ->{ f.typo = 10 }.should.raise( NoMethodError )
    ->{ f[ :typo ] }.should.raise( NoMethodError )
    ->{ f[ :typo ] = 10 }.should.raise( NoMethodError )
    ->{ f[ :query, :typo ] }.should.raise( NoMethodError )

    ->{ f.valid?( :typo ) }.should.raise( ArgumentError )
    ->{ f.valid?( :query, :typo ) }.should.raise( ArgumentError )
    ->{ f.valid?( [ :typo ] ) }.should.raise( ArgumentError )
    ->{ f.valid?( [ :query, :typo ] ) }.should.raise( ArgumentError )
    ->{ f.invalid?( :typo ) }.should.raise( ArgumentError )
    ->{ f.invalid?( :query, :typo ) }.should.raise( ArgumentError )
    ->{ f.invalid?( [ :typo ] ) }.should.raise( ArgumentError )
    ->{ f.invalid?( [ :query, :typo ] ) }.should.raise( ArgumentError )
    ->{ f.valid }.should.raise( ArgumentError )
    ->{ f.valid( :typo ) }.should.raise( ArgumentError )
    ->{ f.valid( :query, :typo ) }.should.raise( ArgumentError )
    ->{ f.valid( [ :typo ] ) }.should.raise( ArgumentError )
    ->{ f.valid( [ :query, :typo ] ) }.should.raise( ArgumentError )
  end

  should 'not overwrite original values via derived forms' do
    f = TestForm.new( query: "x" )
    f.query.should == "x"
    f[ :query ].should == "x"
    
    f.dup.query = "y"
    f.query.should == "x"
    f[ :query ].should == "x"

    f.only( :query ).query = "y"
    f.query.should == "x"
    f[ :query ].should == "x"

    f.only( :query )[ :query ] = "y"
    f.query.should == "x"
    f[ :query ].should == "x"

    f.except( :query ).query = "y"
    f.query.should == "x"
    f[ :query ].should == "x"

    f.except( :query )[ :query ] = "y"
    f.query.should == "x"
    f[ :query ].should == "x"
  end
  
  should 'handle non string values gracefully' do
    f = TestForm.new( query: true, age: 3, rate: 0.35, text: false, opts: [], on: {} )
    ->{ f.validate }.should.not.raise
    f.to_hash.should == { query: true, age: 3, rate: 0.35, text: false }
    f.url_params.should == { q: "true", age: "3", rate: "0.35", text: "false" }
    f.url_query.should == "q=true&age=3&rate=0.35&text=false"
    names( f.incorrect_params ).should == [ :query, :rate, :text ]

    f = TestForm.new( opts: 1 )
    ->{ f.validate }.should.not.raise
    f.to_hash.should == { opts: 1 }
    f.url_params.should == { opts: [ "1" ] }
    f.url_query.should == "opts[]=1"
    names( f.incorrect_params ).should == [ :opts ]

    f = TestForm.new( opts: [ 2.5, true ] )
    ->{ f.validate }.should.not.raise
    f.to_hash.should == { opts: [ 2.5, true ] }
    f.url_params.should == { opts: [ "2.5", "true" ] }
    f.url_query.should == "opts[]=2.5&opts[]=true"
    names( f.incorrect_params ).should == []

    f = TestForm.new( opts: { "foo" => 10, true => false } )
    ->{ f.validate }.should.not.raise
    f.to_hash.should == { opts: { "foo" => 10, true => false } }
    f.url_params.should == { opts: [ '["foo", 10]', '[true, false]' ] }
    f.url_query.should == "opts[]=%5B%22foo%22%2C+10%5D&opts[]=%5Btrue%2C+false%5D"
    names( f.incorrect_params ).should == [ :opts ]

    f = TestForm.new( on: 1 )
    ->{ f.validate }.should.not.raise
    f.to_hash.should == { on: 1 }
    f.url_params.should == { on: { "1" => "" } }
    f.url_query.should == "on[1]="
    names( f.incorrect_params ).should == [ :on ]

    f = TestForm.new( on: { 0 => 1, 2 => 3.4 } )
    ->{ f.validate }.should.not.raise
    f.to_hash.should == { on: { 0 => 1, 2 => 3.4 } }
    f.url_params.should == { on: { "0" => "1", "2" => "3.4" } }
    f.url_query.should == "on[0]=1&on[2]=3.4"
    names( f.incorrect_params ).should == []

    f = TestForm.new( on: [ [ 10, 20 ], [ true, false ] ] )
    ->{ f.validate }.should.not.raise
    f.to_hash.should == { on: [ [ 10, 20 ], [ true, false ] ] }
    f.url_params.should == { on: { "10" => "20", "true" => "false" } }
    f.url_query.should == "on[10]=20&on[true]=false"
    names( f.incorrect_params ).should == [ :on ]

    f = TestForm.new( on: [ 1, true, false ] )
    ->{ f.validate }.should.not.raise
    f.to_hash.should == { on: [ 1, true, false ] }
    f.url_params.should == { on: { "1" => "", "true" => "", "false" => "" } }
    f.url_query.should == "on[1]=&on[true]=&on[false]="
    names( f.incorrect_params ).should == [ :on ]
  end
  
  should 'handle invalid encoding gracefully' do
    s = 255.chr.force_encoding( 'UTF-8' )

    f = TestForm.new( query: s )
    ->{ f.validate }.should.not.raise
    f.should.not.be.valid
    f.error_messages.should == [ "q must use valid encoding" ]
    f.param( :query ).should.not.be.blank
    f.to_hash.should == { query: s }
    f.url_params.should == { q: s }
    f.url_query.should == "q=%FF"

    f = TestForm.new( Rack::Request.new( Rack::MockRequest.env_for( "?q=%ff" ) ) )
    ->{ f.validate }.should.not.raise
    f.should.not.be.valid
    f.error_messages.should == [ "q must use valid encoding" ]
    f.param( :query ).should.not.be.blank
    f.to_hash.should == { query: s.dup.force_encoding( 'BINARY' ) }
    f.url_params.should == { q: s.dup.force_encoding( 'BINARY' ) }
    f.url_query.should == "q=%FF"
  end
  
  should 'make it easy to extend URLs' do
    f = TestForm.new( query: "x", opts: [ 0, 0, 1 ], on: { 0 => 1 }, age: 10, email: nil, password: "", text: " " )
    f.url_params.should == { q: "x", age: "10", text: " ", opts: [ "0", "0", "1" ], on: { "0" => "1" } }
    f.url_query.should == "q=x&age=10&text=+&opts[]=0&opts[]=0&opts[]=1&on[0]=1"
    f.extend_url( "" ).should == "?q=x&age=10&text=+&opts[]=0&opts[]=0&opts[]=1&on[0]=1"
    f.extend_url( "/" ).should == "/?q=x&age=10&text=+&opts[]=0&opts[]=0&opts[]=1&on[0]=1"
    f.extend_url( "/foo" ).should == "/foo?q=x&age=10&text=+&opts[]=0&opts[]=0&opts[]=1&on[0]=1"
    f.extend_url( "/foo?x" ).should == "/foo?x&q=x&age=10&text=+&opts[]=0&opts[]=0&opts[]=1&on[0]=1"
    f.extend_url( URI.parse( "/foo" ) ).should == "/foo?q=x&age=10&text=+&opts[]=0&opts[]=0&opts[]=1&on[0]=1"
    f.extend_url( URI.parse( "/foo?x" ) ).should == "/foo?x&q=x&age=10&text=+&opts[]=0&opts[]=0&opts[]=1&on[0]=1"

    f = TestForm.new
    f.url_params.should == {}
    f.url_query.should == ""
    f.extend_url( "" ).should == ""
    f.extend_url( "/" ).should == "/"
    f.extend_url( "/foo" ).should == "/foo"
    f.extend_url( "/foo?x" ).should == "/foo?x"
    f.extend_url( URI.parse( "/foo" ) ).should == "/foo"
    f.extend_url( URI.parse( "/foo?x" ) ).should == "/foo?x"
  end
  
  should 'provide useful error detecting and reporting methods' do
    # Create new form every time to test that the validation triggers automatically.
    f = ->{ TestForm.new( email: "x", text: "yy" ) }
    f[].should.not.be.valid
    f[].should.be.invalid
    f[].should.be.valid?( :text )
    f[].should.not.be.valid?( :email )
    f[].should.not.be.valid?( :text, :email )
    f[].should.be.valid?( [] )
    f[].should.be.valid?( [ :text ] )
    f[].should.not.be.valid?( [ :email ] )
    f[].should.not.be.valid?( [ :text, :email ] )
    f[].should.not.be.invalid?( :text )
    f[].should.be.invalid?( :email )
    f[].should.be.invalid?( :text, :email )
    f[].should.not.be.invalid?( [] )
    f[].should.not.be.invalid?( [ :text ] )
    f[].should.be.invalid?( [ :email ] )
    f[].should.be.invalid?( [ :text, :email ] )
    f[].valid( :text ).should == "yy"
    f[].valid( :email ).should == nil
    f[].valid( :text, :email ).should == nil
    f[].valid( :text, :password ).should == [ "yy", nil ]
    f[].valid( :text, :text ).should == [ "yy", "yy" ]
    f[].errors.should == { query: [ "q is required" ], email: [ "email address like this is not valid" ] }
    f[].error_messages.should == [ "q is required", "email address like this is not valid" ]
    f[].errors_for( :query ).should == [ "q is required" ]
    f[].error_for( :query ).should == "q is required"
    f[].errors_for( :password ).should == []
    f[].error_for( :password ).should == nil
    
    f = ->{ TestForm.new.report( :query, "msg" ).report( :password, "bad" ) }
    f[].should.not.be.valid
    f[].should.be.invalid
    f[].should.be.valid?( :email )
    f[].should.not.be.valid?( :query )
    f[].should.not.be.valid?( :email, :query )
    f[].should.be.valid?( [] )
    f[].should.be.valid?( [ :email ] )
    f[].should.not.be.valid?( [ :query ] )
    f[].should.not.be.valid?( [ :email, :query ] )
    f[].should.not.be.invalid?( :email )
    f[].should.be.invalid?( :query )
    f[].should.be.invalid?( :email, :query )
    f[].should.not.be.invalid?( [] )
    f[].should.not.be.invalid?( [ :email ] )
    f[].should.be.invalid?( [ :query ] )
    f[].should.be.invalid?( [ :email, :query ] )
    f[].errors.should == { query: [ "q is required", "msg" ], password: [ "bad" ] }
    f[].error_messages.should == [ "q is required", "bad" ]
    f[].errors_for( :query ).should == [ "q is required", "msg" ]
    f[].error_for( :query ).should == "q is required"
    f[].errors_for( :password ).should == [ "bad" ]
    f[].error_for( :password ).should == "bad"
    
    f = TestForm.new
    f.should.be.invalid
    f.set( query: "x" ).should.be.valid
    f.should.be.valid
    f.except( :query ).should.be.invalid
    f.should.be.valid
    f.only( :password ).should.be.invalid
    f.should.be.valid
    f.dup.set( query: "" ).should.be.invalid
    f.should.be.valid
    
    f.query = nil
    f.should.be.valid
    f.validate?.should.be.valid
    f.dup.validate?.should.be.invalid
    f.validate.should.be.invalid
    f.validate!.should.be.invalid

    f.query = "x"
    f.should.be.invalid
    f.validate?.should.be.invalid
    f.dup.validate?.should.be.valid
    f.validate.should.be.invalid
    f.validate!.should.be.valid
    
    f[ :query ] = nil
    f.should.be.invalid
    f.validate?.should.be.invalid
    f.dup.validate?.should.be.invalid
    f.validate.should.be.invalid
    f.validate!.should.be.invalid

    f[ :query ] = "x"
    f.should.be.valid
    f.validate?.should.be.valid
    f.dup.validate?.should.be.valid
    f.validate.should.be.valid
    f.validate!.should.be.valid

    f.clear.should.equal f
    f.should.be.invalid
    f.validate?.should.be.invalid
    f.dup.validate?.should.be.invalid
    f.validate.should.be.invalid
    f.validate!.should.be.invalid

    f.set( query: "x" ).should.equal f
    f.should.be.valid
    f.validate?.should.be.valid
    f.dup.validate?.should.be.valid
    f.validate.should.be.valid
    f.validate!.should.be.valid
  end
  
  should 'support some custom error messages' do
    c = Class.new( FormInput )
    c.param! :q, match: /A/, reject: /B/
    c.copy c[ :q ], name: :c,
      required_msg: '%p must be filled in',
      match_msg: '%p must contain A',
      reject_msg: '%p may not contain B'
    f = c.new
    f.error_messages.should == [ "q is required", "c must be filled in" ]
    f = c.new( q: 'X', c: 'X' )
    f.error_messages.should == [ "q like this is not valid", "c must contain A" ]
    f = c.new( q: 'BA', c: 'BA' )
    f.error_messages.should == [ "q like this is not allowed", "c may not contain B" ]
    f = c.new( q: 'A', c: 'A' )
    f.error_messages.should.be.empty
  end
  
  should 'split parameters into rows as desired' do
    c = Class.new( FormInput )
    c.param :a
    c.param :b, row: 1
    c.param :c, row: 1
    c.param :d
    c.param :e, row: 1
    c.param :f, row: 2
    c.param :g, row: 2
    c.param :h, row: 3
    c.param :i, row: 3
    c.param :j, row: 3
    c.param :k
    
    f = c.new
    f.chunked_params.map{ |x| x.is_a?( Array ) ? x.map{ |y| y.name } : x.name }.should == [
      :a,
      [ :b, :c ],
      :d,
      :e,
      [ :f, :g ],
      [ :h, :i, :j ],
      :k
    ]
    
    f = TestForm.new
    f.chunked_params.should == f.params
    f.chunked_params( f.scalar_params ).should == f.scalar_params
  end
  
end

# EOF #
