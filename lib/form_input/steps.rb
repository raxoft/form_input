# Support for multi-step forms.

class FormInput

  # Turn this form into multi-step form using given steps.
  # Returns self for chaining.
  def self.define_steps( steps )
    @steps = steps = steps.to_hash.dup.freeze

    self.send( :include, StepMethods )

    opts = { filter: ->{ steps.keys.find{ |x| x.to_s == self } }, class: Symbol }

    param :step, opts, type: :hidden
    param :next, opts, type: :ignore
    param :last, opts, type: :hidden
    param :seen, opts, type: :hidden

    self
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
      if correct_step?
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

    # Get parameters relevant for given step.
    def step_params( step )
      fail( ArgumentError, "invalid step name #{step}" ) unless form_steps.key?( step )
      tagged_params( step )
    end

    # Get the parameters relevant for the current step.
    def current_params
      tagged_params( step )
    end

    # Get the parameters irrelevant for the current step.
    def other_params
      untagged_params( step )
    end

    # Get hash mapping defined steps to their names.
    # Note that this is never localized. See step_names instead.
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
    alias raw_step_name step_name

    # Get hash of steps along with their names, for use in a sidebar.
    def step_names
      form_steps.reject{ |k,v| v.nil? }
    end
    alias raw_step_names step_names

    # Get index of given/current step among all steps.
    def step_index( step = self.step )
      steps.index( step ) or fail( ArgumentError, "invalid step name #{step}" )
    end

    # Get first step, or first step among given list of steps, if any.
    def first_step( *args )
      if args.empty?
        steps.first
      else
        args.flatten.compact.min_by{ |x| step_index( x ) }
      end
    end

    # Get last step, or last step among given list of steps, if any.
    def last_step( *args )
      if args.empty?
        steps.last
      else
        args.flatten.compact.max_by{ |x| step_index( x ) }
      end
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

    # Test if the current/given step has no parameters defined.
    def extra_step?( step = self.step )
      step_params( step ).empty?
    end

    # Test if the current/given step has some parameters defined.
    def regular_step?( step = self.step )
      not extra_step?( step )
    end

    # Get steps with no parameters defined.
    def extra_steps
      steps.select{ |step| extra_step?( step ) }
    end

    # Get steps with some parameters defined.
    def regular_steps
      steps.select{ |step| regular_step?( step ) }
    end

    # Filter steps by testing their corresponding parameters with given block. Excludes steps without parameters.
    def filter_steps
      steps.select do |step|
        params = step_params( step )
        yield params unless params.empty?
      end
    end

    # Get steps which have required parameters. Excludes steps without parameters.
    def required_steps
      filter_steps{ |params| params.any?{ |p| p.required? } }
    end

    # Get steps which have no required parameters. Excludes steps without parameters.
    def optional_steps
      filter_steps{ |params| params.none?{ |p| p.required? } }
    end

    # Test if given/current has some required parameters. Considered false for steps without parameters.
    def required_step?( step = self.step )
      step_params( step ).any?{ |p| p.required? }
    end

    # Test if given/current step has no required parameters. Considered true for steps without parameters.
    def optional_step?( step = self.step )
      not required_step?( step )
    end

    # Get steps which have some data filled in. Excludes steps without parameters.
    def filled_steps
      filter_steps{ |params| params.any?{ |p| p.filled? } }
    end

    # Get steps which have no data filled in. Excludes steps without parameters.
    def unfilled_steps
      filter_steps{ |params| params.none?{ |p| p.filled? } }
    end

    # Test if given/current step has some data filled in. Considered true for steps without parameters.
    def filled_step?( step = self.step )
      params = step_params( step )
      params.empty? or params.any?{ |p| p.filled? }
    end

    # Test if given/current step has no data filled in. Considered false for steps without parameters.
    def unfilled_step?( step = self.step )
      not filled_step?( step )
    end

    # Get steps which have all data filled in correctly. Excludes steps without parameters.
    def correct_steps
      filter_steps{ |params| valid?( params ) }
    end

    # Get steps which have some invalid data filled in. Excludes steps without parameters.
    def incorrect_steps
      filter_steps{ |params| invalid?( params ) }
    end

    # Get first step with invalid data, or nil if there is none.
    def incorrect_step
      incorrect_steps.first
    end

    # Test if the current/given step has all data filled in correctly. Considered true for steps without parameters.
    def correct_step?( step = self.step )
      valid?( step_params( step ) )
    end

    # Test if the current/given step has some invalid data filled in. Considered false for steps without parameters.
    def incorrect_step?( step = self.step )
      invalid?( step_params( step ) )
    end

    # Get steps with some parameters enabled. Excludes steps without parameters.
    def enabled_steps
      filter_steps{ |params| params.any?{ |p| p.enabled? } }
    end

    # Get steps with all parameters disabled. Excludes steps without parameters.
    def disabled_steps
      filter_steps{ |params| params.all?{ |p| p.disabled? } }
    end

    # Test if given/current step has some parameters enabled. Considered true for steps without parameters.
    def enabled_step?( step = self.step )
      params = step_params( step )
      params.empty? or params.any?{ |p| p.enabled? }
    end

    # Test if given/current step has all parameters disabled. Considered false for steps without parameters.
    def disabled_step?( step = self.step )
      not enabled_step?( step )
    end

    # Get unfinished steps, those we have not yet visited or visited for the first time.
    def unfinished_steps
      next_steps( seen )
    end

    # Get finished steps, those we have visited or skipped over before.
    def finished_steps
      steps - unfinished_steps
    end

    # Get yet inaccessible steps, excluding the last accessed step.
    def inaccessible_steps
      next_steps( last )
    end

    # Get already accessible steps, including the last accessed step.
    def accessible_steps
      steps - inaccessible_steps
    end

    # Get correct finished steps. Excludes steps without parameters.
    def complete_steps
      correct_steps & finished_steps
    end

    # Get incorrect finished steps. Excludes steps without parameters.
    def incomplete_steps
      incorrect_steps & finished_steps
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
