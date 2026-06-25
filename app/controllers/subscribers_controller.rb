class SubscribersController < ApplicationController
  def new
    # Create an empty subscriber object for the form to use
    @subscriber = Subscriber.new
  end

  def create
    phone_number = subscriber_params[:phone_number]

    # Validate phone number format before doing anything
    unless phone_number.match?(/\A\+[1-9]\d{7,14}\z/)
      @subscriber = Subscriber.new(subscriber_params)
      @subscriber.valid?
      render :new, status: :unprocessable_entity
      return
    end

    # Check if this number already exists in our database
    existing = Subscriber.find_by(phone_number: phone_number)

    if existing
      # They've subscribed before — reactivate their subscription
      existing.update(opted_out: false, expires_at: Time.now + 7.days)
      redirect_to root_path, notice: "You're resubscribed! We'll text you when new slots open up."
    else
      # Brand new subscriber — create a fresh record
      @subscriber = Subscriber.new(subscriber_params)
      @subscriber.expires_at = Time.now + 7.days

      if @subscriber.save
        redirect_to root_path, notice: "You're subscribed! We'll text you when new slots open up."
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  private

  # whitelist only the fields we allow from the form
  def subscriber_params
    params.require(:subscriber).permit(:phone_number)
  end
end
