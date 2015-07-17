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
    @action = @form.step
    @failed = @action if @form.invalid_step? and @form.finished_step?
    
    # That's all until the last steps are reached.
    
    return unless @action == :summary or @action == :post

    # In case the form is still invalid, return to the appropriate step.

    unless @form.valid?
      @failed = @action = @form.step = @form.invalid_step
      return 
    end
    
    # That's all until the last step is reached.
    
    return unless @action == :post
    
    # Finally save the press release.
    
    unless user.create_press_release( @form )
      @action = @form.step = :summary
      @failed = :create
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
      @failed = :invalid unless pr.valid?
      return
    end
    
    # Fetch the data from the post.

    @form = PressReleaseForm.new( request, plan: pr.user.active_plan )
    @action = @form.step
    @failed = @action if @form.invalid_step? and @form.finished_step?
    
    # That's all until the last steps are reached.
    
    return unless @action == :summary or @action == :post
    
    # In case the form is invalid, return to the appropriate step.

    unless @form.valid?
      @failed = @action = @form.step = @form.invalid_step
      return 
    end
    
    # That's all until the last step is reached.
    
    return unless @action == :post
    
    # Finally update the press release.
    
    unless pr.user.update_press_release( pr, @form, user )
      @action = @form.step = :summary
      @failed = :update
      return
    end
    
    redirect owner ? r : AdminController.r( :press_releases )
  end
  
  alias_view :edit, :create
  
end

# EOF #
