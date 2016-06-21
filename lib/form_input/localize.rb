# Simple helper for creating default translation file for existing project.

require 'yaml'
require 'form_input/r18n'

# Primitive helper for converting hash keys to strings.
class Hash
  # Convert all hash keys to strings recursively.
  def stringify_keys
    map{ |k, v| [ k.to_s, v.respond_to?( :stringify_keys ) ? v.stringify_keys : v ] }.to_h
  end
end

class FormInput
  class Parameter
      # Array definining explicit default order of names of parameter options in translation files.
      TRANSLATION_ORDER = %w[title form_title error_title gender plural inflect required_msg msg match_msg reject_msg]

      # Get translation order for given option name.
      def translation_order( name )
        TRANSLATION_ORDER.index( name.to_s ) || TRANSLATION_ORDER.count
      end

      # Get hash of all parameter values which may need to be localized.
      def translation_hash
        opts.select{ |k, v| v.is_a? String }.sort_by{ |k, v| [ translation_order( k ), k ] }.to_h
      end
  end

  # Get hash of all form values which may need to be localized.
  def self.translation_hash
    hash = form_params.map{ |k, v| [ k, v.translation_hash ] }.reject{ |k, v| v.empty? }.to_h
    hash[ :steps ] = form_steps.reject{ |k, v| v.nil? } if form_steps
    hash
  end

  # Get list of all classes inherited from FormInput.
  def self.forms
    ObjectSpace.each_object( Class ).select{ |x| x < FormInput and x.name }.sort_by{ |x| x.name }
  end

  # Get string containing YAML representation of the default R18n translation for all/given FormInput classes.
  def self.default_translation(forms = self.forms)
    hash = forms.map{ |x| [ x.translation_name, x.translation_hash ] }.reject{ |k, v| v.empty? }.to_h
    YAML::dump( { forms: hash }.stringify_keys )
  end
end

# EOF #
