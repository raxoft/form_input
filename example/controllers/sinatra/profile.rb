# Example of simple form handling in Sinatra.

class App < Sinatra::Application

  get '/profile' do

    # Prefill the form with current user profile.

    @form = ProfileForm.new( user.profile_hash )
    slim :profile
  end

  post '/profile' do

    # Validate the posted data.

    @form = ProfileForm.new( request )
    unless @form.valid?
      @state = :report
      return slim :profile
    end

    # Attempt to update the profile.

    unless user.update_profile( @form )
      @state = :update_failed
      return slim :profile
    end

    # Refetch the profile just in case the model changed something, and report success.

    @form = ProfileForm.new( user.profile_hash )
    @state = :done
    slim :profile
  end

end

# EOF #
