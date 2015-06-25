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
  
  should 'accept valid step parameters' do
    t = TestStepsForm.new( request( "?step=email&next=name&seen=intro&last=email" ) )
    t.step.should == :email
    t.next.should == :name
    t.seen.should == :email
    t.last.should == :email
  end

  should 'silently reject invalid step parameters' do
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

end

# EOF #
