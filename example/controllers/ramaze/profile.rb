# Example of simple form handling in Ramaze.

class HomeController < Controller

  # Profile.
  def profile

    # Prefill the form with current user profile.

    unless request.post?
      @form = ProfileForm.new( user.profile_hash )
      return
    end

    # Check new data when the form is posted.

    @form = ProfileForm.new( request )
    unless @form.valid?
      @state = :report
      return
    end

    # Attempt to update the profile.

    unless user.update_profile( @form )
      @state = :update_failed
      return
    end

    # Refetch the profile just in case the model changed something, and report success.

    @form = ProfileForm.new( user.profile_hash )
    @state = :done
  end

end

# EOF #
