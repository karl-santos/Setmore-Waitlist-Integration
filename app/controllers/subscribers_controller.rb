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
      existing.update(opted_out: false, expires_at: Time.now + 7.days)
      send_confirmation_sms(existing.phone_number)
      redirect_to root_path, notice: "You're resubscribed! We'll text you when new slots open up."
    else
      @subscriber = Subscriber.new(subscriber_params)
      @subscriber.expires_at = Time.now + 7.days

      if @subscriber.save
        send_confirmation_sms(@subscriber.phone_number)
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

  def send_confirmation_sms(phone_number)
    client = Twilio::REST::Client.new(
      ENV["TWILIO_ACCOUNT_SID"],
      ENV["TWILIO_AUTH_TOKEN"]
    )
    client.messages.create(
      from: ENV["TWILIO_PHONE_NUMBER"],
      to: phone_number,
      body: "karlblends: You're subscribed to slot notifications for the next 7 days. We'll text you if a new appointment opens up. Reply STOP to opt out anytime."
    )
  rescue => e
    Rails.logger.error "Failed to send confirmation SMS: #{e.message}"
  end
end
