# Example of simple form handling in Ramaze.

class HomeController < Controller

  # Profile.
  def profile

    # Prefill the form with current user profile.

    @form = ProfileForm.new( user.profile_hash )
    return unless request.post?

    # Check new data when the form is posted.

    @form = ProfileForm.new( request )
    @action = :post
    return unless @form.valid?

    # Attempt to update the profile.

    unless user.update_profile( @form )
      @failed = :update
      return
    end

    # Refetch the profile just in case the model changed something, and report success.

    @form = ProfileForm.new( user.profile_hash )
    @action = :done
  end

end

# EOF #
