# encoding: UTF-8

require 'form_input/core'
require 'form_input/steps'
require 'rack/test'

class TestStepsForm < FormInput

  define_steps(
    intro: "Intro",
    email: "Email",
    name: "Name",
    address: "Address",
    message: "Message",
    post: nil,
  )

  param! :email, tag: :email

  param :first_name, tag: :name
  param :last_name, tag: :name

  param :street, tag: :address
  param :city, tag: :address
  param :zip, tag: :address

  param! :message, tag: :message
  param :comment, tag: :message

  param :url, type: :hidden

end

describe FormInput do

  STEP_PARAMS = {
    email: "email=john@foo.com",
    message: "message=blah",
  }

  def request( query )
    Rack::Request.new( Rack::MockRequest.env_for( query ) )
  end

  def names( params )
    params.map{ |x| x && x.name }
  end

  should 'make it possible to define steps' do
    ->{ Class.new( FormInput ).define_steps( a: "A" ) }.should.not.raise
  end

  should 'only define step methods for step forms' do
    f = FormInput.new
    t = TestStepsForm.new
    for name in FormInput::StepMethods.instance_methods
      f.should.not.respond_to name
      t.should.respond_to name
    end
  end

  should 'provide parameters for keeping track of step state' do
    f = Class.new( FormInput ).define_steps( a: "A" ).new
    names( f.optional_params ).should == [ :step, :next, :last, :seen ]
    names( f.enabled_params ).should == [ :step, :next, :last, :seen ]
    names( f.hidden_params ).should == [ :step, :last, :seen ]
    names( f.ignored_params ).should == [ :next ]
    names( f.visible_params ).should == []
    names( f.scalar_params ).should == [ :step, :next, :last, :seen ]
  end

  should 'accept valid step parameters' do
    t = TestStepsForm.new( request( "?step=email&next=name&seen=intro&last=email" ) )
    t.step.should == :email
    t.next.should == :name
    t.seen.should == :email
    t.last.should == :email
  end

  should 'silently ignore invalid step parameters' do
    t = TestStepsForm.new( request( "?step=a&next=b&seen=c&last=d" ) )
    t.step.should == :intro
    t.next.should == :intro
    t.seen.should == nil
    t.last.should == :intro
  end

  should 'allow progressing through all steps in turn' do
    seen = []
    ref = [
      "step=intro&next=intro&last=intro",
      "step=email&next=email&last=email&seen=intro",
      "step=name&next=name&last=name&seen=email&email=john%40foo.com",
      "step=address&next=address&last=address&seen=name&email=john%40foo.com",
      "step=message&next=message&last=message&seen=address&email=john%40foo.com",
      "step=post&next=post&last=post&seen=message&email=john%40foo.com&message=blah",
      "step=post&next=post&last=post&seen=post&email=john%40foo.com&message=blah",
    ]

    t = TestStepsForm.new
    until t.seen == :post
      t.url_query.should == ref.shift

      t.step.should == t.next_step( seen.last )
      t.next.should == t.step
      t.seen.should == seen.last
      t.last.should == t.step

      seen << t.step

      params = STEP_PARAMS[ t.step ]

      t.next = t.next_step
      t = TestStepsForm.new( request( t.extend_url( "?#{params}" ) ) )
    end

    t.url_query.should == ref.shift
    ref.should.be.empty?
    seen.should == t.steps
  end

  should 'refuse progressing until all step parameters are valid' do
    ref = [
      "step=intro&next=intro&last=intro",
      "step=email&next=email&last=email&seen=intro",
      "step=email&next=name&last=email&seen=email",
      "step=name&next=name&last=name&seen=email&email=john%40foo.com",
      "step=address&next=address&last=address&seen=name&email=john%40foo.com",
      "step=message&next=message&last=message&seen=address&email=john%40foo.com",
      "step=message&next=post&last=message&seen=message&email=john%40foo.com",
      "step=post&next=post&last=post&seen=message&email=john%40foo.com&message=blah",
      "step=post&next=post&last=post&seen=post&email=john%40foo.com&message=blah",
      "step=post&next=post&last=post&seen=post&email=john%40foo.com&message=blah",
    ]

    t = TestStepsForm.new
    until ref.empty?
      t.url_query.should == ref.shift
      params = STEP_PARAMS[ t.seen ]
      t.next = t.next_step
      t = TestStepsForm.new( request( t.extend_url( "?#{params}" ) ) )
    end
  end

  should 'allow stepping back through all steps in turn' do
    seen = []
    ref = [
      "step=post&next=post&last=post&seen=post&email=john%40foo.com&message=blah",
      "step=message&next=message&last=post&seen=post&email=john%40foo.com&message=blah",
      "step=address&next=address&last=post&seen=post&email=john%40foo.com&message=blah",
      "step=name&next=name&last=post&seen=post&email=john%40foo.com&message=blah",
      "step=email&next=email&last=post&seen=post&email=john%40foo.com&message=blah",
      "step=intro&next=intro&last=post&seen=post&email=john%40foo.com&message=blah",
      "step=intro&next=intro&last=post&seen=post&email=john%40foo.com&message=blah",
    ]

    t = TestStepsForm.new( request( "?#{ref.first}" ) )
    until ref.size == 1
      t.url_query.should == ref.shift
      seen << t.step
      t.next = t.previous_step
      t = TestStepsForm.new( request( t.extend_url( "?" ) ) )
    end

    t.url_query.should == ref.shift
    ref.should.be.empty?
    seen.should == t.steps.reverse
  end

  should 'refuse stepping back across invalid steps' do
    ref = [
      "step=post&next=intro&last=post&seen=post",
      "step=message&next=message&last=post&seen=post",
      "step=message&next=address&last=post&seen=post",
      "step=address&next=address&last=post&seen=post&message=blah",
      "step=name&next=name&last=post&seen=post&message=blah",
      "step=email&next=email&last=post&seen=post&message=blah",
      "step=email&next=intro&last=post&seen=post&message=blah",
      "step=intro&next=intro&last=post&seen=post&email=john%40foo.com&message=blah",
      "step=intro&next=intro&last=post&seen=post&email=john%40foo.com&message=blah",
    ]

    t = TestStepsForm.new.unlock_steps
    t.step = t.last_step
    until ref.empty?
      t.url_query.should == ref.shift
      params = STEP_PARAMS[ t.step ] if t.step != t.next
      t.next = t.previous_step
      t = TestStepsForm.new( request( t.extend_url( "?#{params}" ) ) )
    end
  end

  should 'allow getting parameters of individual steps' do
    t = TestStepsForm.new( request( "?step=name&next=address&seen=message&last=message" ) )
    names( t.current_params ).should == [ :street, :city, :zip ]
    names( t.other_params ).should == [ :step, :next, :last, :seen, :email, :first_name, :last_name, :message, :comment, :url ]
    names( t.step_params( :email ) ).should == [ :email ]
    names( t.step_params( :name ) ).should == [ :first_name, :last_name ]
    names( t.step_params( :post ) ).should == []
    ->{ t.step_params( :foo ) }.should.raise ArgumentError
    ->{ t.step_params( nil ) }.should.raise ArgumentError
  end

  should 'provide methods for getting details about steps' do
    t = TestStepsForm.new( request( "?step=name&next=address&seen=name&last=name&first_name=John&comment=Blah" ) )

    t.form_steps.should == { intro: "Intro", email: "Email", name: "Name", address: "Address", message: "Message", post: nil }
    t.steps.should == [ :intro, :email, :name, :address, :message, :post ]

    t.step_name.should == "Address"
    t.step_name( :email ).should == "Email"
    t.step_name( :foo ).should == nil
    t.step_name( nil ).should == nil
    t.step_names.should == { intro: "Intro", email: "Email", name: "Name", address: "Address", message: "Message" }

    t.step_index.should == 3
    t.step_index( :intro ).should == 0
    t.step_index( :post ).should == 5
    ->{ t.step_index( :foo ) }.should.raise ArgumentError
    ->{ t.step_index( nil ) }.should.raise ArgumentError

    t.step_before?( :intro ).should.be.false
    t.step_before?( :name ).should.be.false
    t.step_before?( :address ).should.be.false
    t.step_before?( :message ).should.be.true
    t.step_before?( :post ).should.be.true

    t.step_after?( :intro ).should.be.true
    t.step_after?( :name ).should.be.true
    t.step_after?( :address ).should.be.false
    t.step_after?( :message ).should.be.false
    t.step_after?( :post ).should.be.false

    t.first_step.should == :intro
    t.first_step( nil ).should == nil
    t.first_step( nil, nil ).should == nil
    t.first_step( :post ).should == :post
    t.first_step( :address, :email ).should == :email
    t.first_step( nil, :name, :address ).should == :name
    t.first_step( [ :post, nil, :email ] ).should == :email
    ->{ t.first_step( :foo ) }.should.raise ArgumentError
    ->{ t.first_step( :email, :foo ) }.should.raise ArgumentError
    ->{ t.first_step( [ nil, :foo, :address] ) }.should.raise ArgumentError

    t.last_step.should == :post
    t.last_step( nil ).should == nil
    t.last_step( nil, nil ).should == nil
    t.last_step( :post ).should == :post
    t.last_step( :address, :email ).should == :address
    t.last_step( nil, :name, :address ).should == :address
    t.last_step( [ :post, nil, :email ] ).should == :post
    ->{ t.last_step( :foo ) }.should.raise ArgumentError
    ->{ t.last_step( :email, :foo ) }.should.raise ArgumentError
    ->{ t.last_step( [ nil, :foo, :address] ) }.should.raise ArgumentError

    t.first_step?.should.be.false
    t.first_step?( :intro ).should.be.true
    t.first_step?( :email ).should.be.false
    t.first_step?( :name ).should.be.false
    t.first_step?( :address ).should.be.false
    t.first_step?( :message ).should.be.false
    t.first_step?( :post ).should.be.false
    t.first_step?( nil ).should.be.false
    t.first_step?( :foo ).should.be.false

    t.last_step?.should.be.false
    t.last_step?( :intro ).should.be.false
    t.last_step?( :email ).should.be.false
    t.last_step?( :name ).should.be.false
    t.last_step?( :address ).should.be.false
    t.last_step?( :message ).should.be.false
    t.last_step?( :post ).should.be.true
    t.last_step?( nil ).should.be.false
    t.last_step?( :foo ).should.be.false

    t.previous_steps.should == [ :intro, :email, :name ]
    t.previous_steps( nil ).should == []
    t.previous_steps( :intro ).should == []
    t.previous_steps( :name ).should == [ :intro, :email ]
    t.previous_steps( :post ).should == [ :intro, :email, :name, :address, :message ]
    t.previous_steps( :foo ).should == []

    t.next_steps.should == [ :message, :post ]
    t.next_steps( nil ).should == [ :intro, :email, :name, :address, :message, :post ]
    t.next_steps( :intro ).should == [ :email, :name, :address, :message, :post ]
    t.next_steps( :name ).should == [ :address, :message, :post ]
    t.next_steps( :post ).should == []
    t.next_steps( :foo ).should == [ :intro, :email, :name, :address, :message, :post ]

    t.previous_step.should == :name
    t.previous_step( nil ).should == nil
    t.previous_step( :intro ).should == nil
    t.previous_step( :name ).should == :email
    t.previous_step( :post ).should == :message
    t.previous_step( :foo ).should == nil

    t.next_step.should == :message
    t.next_step( nil ).should == :intro
    t.next_step( :intro ).should == :email
    t.next_step( :name ).should == :address
    t.next_step( :post ).should == nil
    t.next_step( :foo ).should == :intro

    t.previous_step_name.should == "Name"
    t.next_step_name.should == "Message"

    t.extra_step?.should.be.false
    t.extra_step?( :intro ).should.be.true
    t.extra_step?( :email ).should.be.false
    t.extra_step?( :name ).should.be.false
    t.extra_step?( :address ).should.be.false
    t.extra_step?( :message ).should.be.false
    t.extra_step?( :post ).should.be.true
    ->{ t.extra_step?( nil ) }.should.raise ArgumentError
    ->{ t.extra_step?( :foo ) }.should.raise ArgumentError

    t.regular_step?.should.be.true
    t.regular_step?( :intro ).should.be.false
    t.regular_step?( :email ).should.be.true
    t.regular_step?( :name ).should.be.true
    t.regular_step?( :address ).should.be.true
    t.regular_step?( :message ).should.be.true
    t.regular_step?( :post ).should.be.false
    ->{ t.regular_step?( nil ) }.should.raise ArgumentError
    ->{ t.regular_step?( :foo ) }.should.raise ArgumentError

    t.extra_steps.should == [ :intro, :post ]
    t.regular_steps.should == [ :email, :name, :address, :message ]

    t.required_step?.should.be.false
    t.required_step?( :intro ).should.be.false
    t.required_step?( :email ).should.be.true
    t.required_step?( :name ).should.be.false
    t.required_step?( :address ).should.be.false
    t.required_step?( :message ).should.be.true
    t.required_step?( :post ).should.be.false
    ->{ t.required_step?( nil ) }.should.raise ArgumentError
    ->{ t.required_step?( :foo ) }.should.raise ArgumentError

    t.optional_step?.should.be.true
    t.optional_step?( :intro ).should.be.true
    t.optional_step?( :email ).should.be.false
    t.optional_step?( :name ).should.be.true
    t.optional_step?( :address ).should.be.true
    t.optional_step?( :message ).should.be.false
    t.optional_step?( :post ).should.be.true
    ->{ t.optional_step?( nil ) }.should.raise ArgumentError
    ->{ t.optional_step?( :foo ) }.should.raise ArgumentError

    t.required_steps.should == [ :email, :message ]
    t.optional_steps.should == [ :name, :address ]

    t.filled_step?.should.be.false
    t.filled_step?( :intro ).should.be.true
    t.filled_step?( :email ).should.be.false
    t.filled_step?( :name ).should.be.true
    t.filled_step?( :address ).should.be.false
    t.filled_step?( :message ).should.be.true
    t.filled_step?( :post ).should.be.true
    ->{ t.filled_step?( nil ) }.should.raise ArgumentError
    ->{ t.filled_step?( :foo ) }.should.raise ArgumentError

    t.unfilled_step?.should.be.true
    t.unfilled_step?( :intro ).should.be.false
    t.unfilled_step?( :email ).should.be.true
    t.unfilled_step?( :name ).should.be.false
    t.unfilled_step?( :address ).should.be.true
    t.unfilled_step?( :message ).should.be.false
    t.unfilled_step?( :post ).should.be.false
    ->{ t.unfilled_step?( nil ) }.should.raise ArgumentError
    ->{ t.unfilled_step?( :foo ) }.should.raise ArgumentError

    t.filled_steps.should == [ :name, :message ]
    t.unfilled_steps.should == [ :email, :address ]

    t.correct_step?.should.be.true
    t.correct_step?( :intro ).should.be.true
    t.correct_step?( :email ).should.be.false
    t.correct_step?( :name ).should.be.true
    t.correct_step?( :address ).should.be.true
    t.correct_step?( :message ).should.be.false
    t.correct_step?( :post ).should.be.true
    ->{ t.correct_step?( nil ) }.should.raise ArgumentError
    ->{ t.correct_step?( :foo ) }.should.raise ArgumentError

    t.incorrect_step?.should.be.false
    t.incorrect_step?( :intro ).should.be.false
    t.incorrect_step?( :email ).should.be.true
    t.incorrect_step?( :name ).should.be.false
    t.incorrect_step?( :address ).should.be.false
    t.incorrect_step?( :message ).should.be.true
    t.incorrect_step?( :post ).should.be.false
    ->{ t.incorrect_step?( nil ) }.should.raise ArgumentError
    ->{ t.incorrect_step?( :foo ) }.should.raise ArgumentError

    t.correct_steps.should == [ :name, :address ]
    t.incorrect_steps.should == [ :email, :message ]
    t.incorrect_step.should == :email
    t.dup.set( email: "x@foo.com" ).incorrect_step.should == :message
    t.dup.set( email: "x@foo.com", message: "bar" ).incorrect_step.should == nil

    t.enabled_step?.should.be.true
    t.enabled_step?( :intro ).should.be.true
    t.enabled_step?( :email ).should.be.true
    t.enabled_step?( :name ).should.be.true
    t.enabled_step?( :address ).should.be.true
    t.enabled_step?( :message ).should.be.true
    t.enabled_step?( :post ).should.be.true
    ->{ t.enabled_step?( nil ) }.should.raise ArgumentError
    ->{ t.enabled_step?( :foo ) }.should.raise ArgumentError

    t.disabled_step?.should.be.false
    t.disabled_step?( :intro ).should.be.false
    t.disabled_step?( :email ).should.be.false
    t.disabled_step?( :name ).should.be.false
    t.disabled_step?( :address ).should.be.false
    t.disabled_step?( :message ).should.be.false
    t.disabled_step?( :post ).should.be.false
    ->{ t.disabled_step?( nil ) }.should.raise ArgumentError
    ->{ t.disabled_step?( :foo ) }.should.raise ArgumentError

    t.enabled_steps.should == [ :email, :name, :address, :message ]
    t.disabled_steps.should == []
    c = Class.new( FormInput )
    c.define_steps( TestStepsForm.form_steps )
    c.copy( t.visible_params, disabled: ->{ [ :first_name, :last_name, :comment ].include? name } )
    f = c.new
    names( f.disabled_params ).should == [ :first_name, :last_name, :comment ]
    f.enabled_steps.should == [ :email, :address, :message ]
    f.disabled_steps.should == [ :name ]

    t.finished_steps.should == [ :intro, :email, :name ]
    t.unfinished_steps.should == [ :address, :message, :post ]
    t.accessible_steps.should == [ :intro, :email, :name, :address ]
    t.inaccessible_steps.should == [ :message, :post ]
    t.complete_steps.should == [ :intro, :name ]
    t.incomplete_steps.should == [ :email ]
    t.good_steps.should == [ :name ]
    t.bad_steps.should == [ :email ]

    check = ->( form ){
      %w[ finished_step unfinished_step accessible_step inaccessible_step complete_step incomplete_step good_step bad_step ].each do |name|
        method = "#{name}?"
        form.send( method ).should == form.send( method, form.step )
        form.steps.each{ |x| form.send( method, x ).should == form.send( "#{name}s" ).include?( x ) }
        ->{ form.send( method, nil ) }.should.raise ArgumentError
        ->{ form.send( method, :foo ) }.should.raise ArgumentError
      end
    }

    check.call(t)

    t = TestStepsForm.new
    t.finished_steps.should == []
    t.unfinished_steps.should == [ :intro, :email, :name, :address, :message, :post ]
    t.accessible_steps.should == [ :intro ]
    t.inaccessible_steps.should == [ :email, :name, :address, :message, :post ]
    t.complete_steps.should == []
    t.incomplete_steps.should == []
    t.good_steps.should == []
    t.bad_steps.should == []

    check.call(t)

    t = TestStepsForm.new.unlock_steps
    t.finished_steps.should == [ :intro, :email, :name, :address, :message, :post ]
    t.unfinished_steps.should == []
    t.accessible_steps.should == [ :intro, :email, :name, :address, :message, :post ]
    t.inaccessible_steps.should == []
    t.complete_steps.should == [ :intro, :name, :address, :post ]
    t.incomplete_steps.should == [ :email, :message ]
    t.good_steps.should == []
    t.bad_steps.should == [ :email, :message ]

    check.call(t)
  end

end

# EOF #
