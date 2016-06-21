# encoding: UTF-8

require_relative 'helper'

require 'form_input/localize'

class TestLocalizeForm < FormInput

  define_steps(
    one: "First",
    two: "Second",
    three: "Third",
    four: nil,
  )
  param :simple, "String"
  param :complex, "Title",
    subtitle: "Subtitle",
    form_title: "Form Title",
    error_title: "Error Title",
    required_msg: "%p is required!",
    match: /[a-z]/i,
    msg: "%p must contain at least one letter",
    reject: /\d/,
    reject_msg: "%p must not contain a digit",
    help: "Help",
    placeholder: "Placeholder"
  param :utf, "ěščřžýáíéúůďťň"
  param :yaml, '%', msg: '{}'

end

describe FormInput do

  should 'provide helper which returns all form classes' do
    FormInput.forms.each{ |x| x.should < FormInput }
    FormInput.forms.should.include TestLocalizeForm
  end

  should 'provide helper to create default translation file' do
    text = FormInput.default_translation( [ TestLocalizeForm ] )
    name = File.expand_path( "#{__FILE__}/../localize/en.yml" )
    if File.exists?( name )
      YAML.load( text ).should == YAML.load( File.read( name ) )
    else
      File.write( name, text )
    end
  end

end

# EOF #
