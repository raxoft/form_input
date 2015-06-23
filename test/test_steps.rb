# encoding: UTF-8

require 'form_input/core'
require 'form_input/steps'
require 'rack/test'

class TestStepsForm < FormInput

  define_steps(
    name: "Name",
    email: "Email",
    address: "Address",
    message: "Message",
    post: nil,
  )
  
  param :first_name, tag: :name
  param :last_name, tag: :name
  
  param! :email, tag: :email
  
  param :street, tag: :address
  param :city, tag: :address
  param :zip, tag: :address
  
  param! :message, tag: :message
  
  param :url

end

describe FormInput do

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
    t = TestStepsForm.new( request( "?step=email&next=address&seen=name&last=email" ) )
    t.step.should == :email
    t.next.should == :address
    t.seen.should == :email
    t.last.should == :email
  end

  should 'silently reject invalid step parameters' do
    t = TestStepsForm.new( request( "?step=a&next=b&seen=c&last=d" ) )
    t.step.should == :name
    t.next.should == :name
    t.seen.should == nil
    t.last.should == :name
  end

end

# EOF #
