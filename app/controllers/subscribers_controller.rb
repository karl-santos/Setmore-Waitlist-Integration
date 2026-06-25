class SubscribersController < ApplicationController
  def new
    # Create an empty subscriber object for the form to use
    @subscriber = Subscriber.new
  end

  def create
    # Build a subscriber from the form data
    @subscriber = Subscriber.new(subscriber_params)

    # Set the expiry to 7 days from now
    @subscriber.expires_at = Time.now + 7.days

    if @subscriber.save
      # If saved successfully, show a success message
      redirect_to root_path, notice: "You're subscribed! We'll text you when new slots open up."
    else
      # If validation failed (e.g. duplicate number), show the form again with errors
      render :new, status: :unprocessable_entity
    end
  end

  private

  # whitelist only the fields we allow from the form
  def subscriber_params
    params.require(:subscriber).permit(:phone_number)
  end
end
