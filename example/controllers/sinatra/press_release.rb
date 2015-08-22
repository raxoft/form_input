# The press release controller - example of a complex multistep form handling in Sinatra.

class App < Sinatra::Base

  # Create press release - start.
  get '/pr/create' do

    # Start with fresh form, prefilled with some user info.

    @form = PressReleaseForm.new(
      user.active_plan,
      date: Time.now,
      city: user.profile.city,
      state: user.profile.state,
      country: user.profile.country,
      contact_name: user.full_name,
      contact_organization: user.profile.company,
      contact_phone: user.profile.phone,
      contact_email: user.email,
    )
    slim :press_release
  end

  # Create press release - creation.
  post '/pr/create' do

    # Process the data from the post.

    @form = PressReleaseForm.new( user.active_plan, request )
    unless process_form( @form )
      return slim :press_release
    end

    # Save the press release.

    unless user.create_press_release( @form )
      @form.step = :summary
      @state = :create_failed
      return slim :press_release
    end

    redirect '/'
  end

  # Edit press release - start.
  get '/pr/edit/:hid' do |hid|

    # Fetch the existing press release.
    # Note that it can be edited by admins in addition to its owner.

    pr = get_press_release( hid )
    @form = PressReleaseForm.new( pr.user.active_plan, pr.form_hash ).unlock_steps
    slim :press_release
  end

  # Edit press release - update.
  post '/pr/edit/:hid' do |hid|

    # Process the data from the post.

    pr = get_press_release( hid )
    @form = PressReleaseForm.new( pr.user.active_plan, request )
    unless process_form( @form )
      return slim :press_release
    end

    # Update the press release.

    unless pr.user.update_press_release( pr, @form, user )
      @form.step = :summary
      @state = :update_failed
      return slim :press_release
    end

    redirect '/'
  end

  # Get the press release for given hashed id.
  def get_press_release( hid )
    not_found unless pr = PressRelease.from_hid( hid )

    owner = ( pr.user_id == user.id )
    forbidden unless owner or user.admin?

    pr
  end

  # Common logic for processing the form steps.
  def process_form( form )

    # Report errors whenever there are some in the currently finished step.

    @state = :report if form.invalid_step? and form.finished_step?

    # That's all until the last steps are reached.

    step = form.step
    return unless step == :summary or step == :post

    # In case the form is still invalid, return to the appropriate step.

    unless form.valid?
      form.step = form.invalid_step
      @state = :report
      return
    end

    # That's all until the last step is reached.

    return step == :post
  end

end

# EOF #
