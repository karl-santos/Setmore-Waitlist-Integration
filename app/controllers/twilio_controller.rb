class TwilioController < ApplicationController
  # Skip CSRF protection for this endpoint
  # Twilio sends POST requests from their servers, not from a browser form
  # so Rails' CSRF protection would reject them
  skip_before_action :verify_authenticity_token, only: [ :inbound ]

  def inbound
    # Twilio sends the sender's phone number as "From"
    # and the message content as "Body"
    from = params["From"]
    body = params["Body"].to_s.strip.downcase

    # Find the subscriber by their phone number
    subscriber = Subscriber.find_by(phone_number: from)

    if body == "stop"
      # Opt them out if they exist in the database
      if subscriber
        subscriber.update(opted_out: true)
        Rails.logger.info "Subscriber #{from} opted out via STOP"
      end

    elsif body == "start"
      # Reactivate their subscription if they exist
      if subscriber
        subscriber.update(opted_out: false, expires_at: Time.now + 7.days)
        Rails.logger.info "Subscriber #{from} resubscribed via START"
      end
    end

    # Twilio expects a TwiML XML response
    # An empty Response means no reply text is sent back
    render xml: "<Response></Response>"
  end
end
