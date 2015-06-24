# Support for multi-step forms.

class FormInput

  # Turn this form into multi-step form using given steps.
  def self.define_steps( steps )
    @steps = steps = steps.to_hash.dup.freeze

    self.send( :include, StepMethods )

    opts = { filter: ->{ steps.keys.find{ |x| x.to_s == self } }, class: Symbol }

    param :step, opts, type: :hidden
    param :next, opts, type: :ignore
    param :last, opts, type: :hidden
    param :seen, opts, type: :hidden
  end
  
  # Get hash mapping defined steps to their names, or nil if there are none.
  def self.form_steps
    @steps
  end

  # Additional methods used for multi-step form processing.
  module StepMethods

    # Initialize new instance.
    def initialize( *args )
      super
      self.seen = last_step( seen, step )
      self.step ||= steps.first
      self.next ||= step
      self.last ||= step
      if current_params.all?{ |p| p.valid? }
        self.step = self.next
        self.seen = last_step( seen, previous_step( step ) )
      end
      self.last = last_step( step, last )
    end
    
    # Make all steps instantly available.
    # Returns self for chaining.
    def unlock_steps
      self.last = self.seen = steps.last
      self
    end
    
    # Get the parameters relevant for the current step.
    def current_params
      tagged_params( step )
    end
    
    # Get the parameters irrelevant for the current step.
    def other_params
      untagged_params( step )
    end
    
    # Get index of given/current step among all steps.
    def step_index( step = self.steps )
      steps.index( step )
    end
    
    # Get first step among given list of steps.
    def first_step( *steps )
      steps.flatten.compact.min_by{ |x| step_index( x ) }
    end
    
    # Get last step among given list of steps.
    def last_step( *steps )
      steps.flatten.compact.max_by{ |x| step_index( x ) }
    end
    
    # Get hash mapping defined steps to their names.
    def form_steps
      self.class.form_steps
    end
    
    # Get allowed form steps as list of symbols.
    def steps
      form_steps.keys
    end
    
    # Get name of current or given step, if any.
    def step_name( step = self.step )
      form_steps[ step ]
    end
    
    # Get hash of steps along with their names, for use as sidebar.
    def step_names
      form_steps.dup.delete_if{ |k,v| v.nil? }
    end
    
    # Get steps before given/current step.
    def previous_steps( step = self.step )
      index = steps.index( step ) || 0
      steps.first( index )
    end
    
    # Get steps after given/current step.
    def next_steps( step = self.step )
      index = steps.index( step ) || -1
      steps[ index + 1 .. -1 ]
    end
    
    # Get the next step, or nil.
    def next_step( step = self.step )
      next_steps( step ).first
    end
    
    # Get the previous step, or nil.
    def previous_step( step = self.step )
      previous_steps( step ).last
    end
    
    # Filter steps by testing their corresponding parameters with given block.
    def filter_steps
      steps.select do |step|
        params = tagged_params( step )
        yield params unless params.empty?
      end
    end
    
    # Get steps which have some data filled in.
    def filled_steps
      filter_steps{ |params| params.any?{ |p| p.filled? } }
    end
    
    # Get steps which have no data filled in.
    def unfilled_steps
      filter_steps{ |params| params.none?{ |p| p.filled? } }
    end
    
    # Get steps which have required parameters.
    def required_steps
      filter_steps{ |params| params.any?{ |p| p.required? } }
    end
    
    # Get steps which have no required parameters.
    def optional_steps
      filter_steps{ |params| params.none?{ |p| p.required? } }
    end
    
    # Get steps which have valid data filled in.
    def valid_steps
      filter_steps{ |params| valid?( *params ) }
    end
    
    # Get steps which have invalid data filled in.
    def invalid_steps
      filter_steps{ |params| invalid?( *params ) }
    end
    
    # Get first step with invalid data, or nil if there is none.
    def invalid_step
      invalid_steps.first
    end
    
    # Test if given/current step is invalid.
    def invalid_step?( step = self.step )
      invalid_steps.include?( step )
    end
    
    # Get steps which are enabled.
    def enabled_steps
      filter_steps{ |params| params.all?{ |p| p.enabled? } }
    end
    
    # Get steps which are disabled.
    def disabled_steps
      filter_steps{ |params| params.any?{ |p| p.disabled? } }
    end
    
    # Test if given/current step is disabled.
    def disabled_step?( step = self.step )
      disabled_steps.include?( step )
    end
    
    # Get unfinished steps, those we have not yet visited or visited for the first time.
    def unfinished_steps
      next_steps( seen )
    end
    
    # Get finished steps, those we have visited or skipped over before.
    def finished_steps
      steps - unfinished_steps
    end
    
    # Test if given/current step is finished.
    def finished_step?( step = self.step )
      finished_steps.include?( step )
    end
    
    # Get inaccessible steps, excluding the last accessed step.
    def inaccessible_steps
      next_steps( last )
    end
    
    # Get accessible steps, including the last accessed step.
    def accessible_steps
      steps - inaccessible_steps
    end
    
    # Get valid finished steps.
    def complete_steps
      valid_steps & finished_steps
    end
    
    # Get invalid finished steps.
    def incomplete_steps
      invalid_steps & finished_steps
    end
    
    # Get steps which shell be checked off as ok in the sidebar.
    def good_steps
      complete_steps & filled_steps
    end
    
    # Get steps which shell be marked as having errors in the sidebar.
    def bad_steps
      incomplete_steps
    end
    
  end
  
end

# EOF #
