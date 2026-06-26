class TwilioController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :inbound ]

  ADMIN_PHONE = ENV["ADMIN_PHONE"]

  def inbound
    from = params["From"]
    body = params["Body"].to_s.strip.downcase

    if from == ADMIN_PHONE
      handle_admin_command(body)
    else
      handle_subscriber_command(from, body)
    end

    render xml: "<Response></Response>"
  end

  private

  def handle_admin_command(body)
    case body
    when "poll"
      PollSlotsJob.perform_later
      send_sms(ADMIN_PHONE, "Poll job queued. Check logs.")
    when "status"
      count = Subscriber.active.count
      send_sms(ADMIN_PHONE, "Active subscribers: #{count}")
    when "slots"
      slots = AvailableSlot.order(:slot_datetime).pluck(:slot_datetime)
      if slots.empty?
        send_sms(ADMIN_PHONE, "No slots in database.")
      else
        message = slots.map { |s| s.strftime("%a %b %-d %-I:%M %p") }.join("\n")
        send_sms(ADMIN_PHONE, message)
      end
    else
      send_sms(ADMIN_PHONE, "Commands: poll, status, slots")
    end
  end

  def handle_subscriber_command(from, body)
    subscriber = Subscriber.find_by(phone_number: from)

    if body == "stop"
      if subscriber
        subscriber.update(opted_out: true)
        Rails.logger.info "Subscriber #{from} opted out via STOP"
      end
    end
  end

  def send_sms(to, message)
    client = Twilio::REST::Client.new(
      ENV["TWILIO_ACCOUNT_SID"],
      ENV["TWILIO_AUTH_TOKEN"]
    )
    client.messages.create(
      from: ENV["TWILIO_PHONE_NUMBER"],
      to: to,
      body: message
    )
  end
end
