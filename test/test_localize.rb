# encoding: UTF-8

require_relative 'helper'

require 'form_input/localize'

class TestLocalizeForm < FormInput
  param :simple, "String"
  param :utf, "ěščřžýáíéúůďťň"
  param :yaml, '%', msg: '{}'
end

describe FormInput do

  should 'provide helper to create default translation file' do
    text = FormInput.default_translation
    name = File.expand_path( "#{__FILE__}/../localize/en.yml" )
    if File.exists?( name )
      text.should == File.read( name )
    else
      File.write( name, text )
    end
  end

end

# EOF #
