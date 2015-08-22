# The press release controller - example of a complex multistep form handling in Ramaze.

class PRController < Controller

  # Create press release.
  def create

    # Start with fresh form.

    unless request.post?
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
      return
    end

    # Fetch the data from the post.

    @form = PressReleaseForm.new( user.active_plan, request )
    @state = :report if @form.invalid_step? and @form.finished_step?

    # That's all until the last steps are reached.

    step = @form.step
    return unless step == :summary or step == :post

    # In case the form is still invalid, return to the appropriate step.

    unless @form.valid?
      @form.step = @form.invalid_step
      @state = :report
      return
    end

    # That's all until the last step is reached.

    return unless step == :post

    # Finally save the press release.

    unless user.create_press_release( @form )
      @form.step = :summary
      @state = :create_failed
      return
    end

    redirect r
  end

  # Edit press release.
  def edit( hid )
    not_found unless pr = PressRelease.from_hid( hid )

    owner = ( pr.user_id == user.id )
    forbidden unless owner or user.admin?

    unless request.post?
      @form = PressReleaseForm.new( pr.user.active_plan, pr.form_hash ).unlock_steps
      @state = :invalid unless pr.valid?
      return
    end

    # Fetch the data from the post.

    @form = PressReleaseForm.new( pr.user.active_plan, request )
    @state = :report if @form.invalid_step? and @form.finished_step?

    # That's all until the last steps are reached.

    step = @form.step
    return unless step == :summary or step == :post

    # In case the form is invalid, return to the appropriate step.

    unless @form.valid?
      @form.step = @form.invalid_step
      @state = :report
      return
    end

    # That's all until the last step is reached.

    return unless step == :post

    # Finally update the press release.

    unless pr.user.update_press_release( pr, @form, user )
      @form.step = :summary
      @state = :update_failed
      return
    end

    redirect owner ? r : AdminController.r( :press_releases )
  end

  alias_view :edit, :create

end

# EOF #
