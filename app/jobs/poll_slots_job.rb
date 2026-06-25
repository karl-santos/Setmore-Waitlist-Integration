class PollSlotsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "PollSlotsJob starting..."

    client = SetmoreClient.new

    # This hash will collect new slots across all 7 days
    # before we send any notifications
    # Format: { date => ["1:00 PM", "1:40 PM"], date => ["5:00 PM"] }
    all_new_slots = {}

    # Loop through the next 7 days
    days_from_now = 0
    while days_from_now <= 6
      date = Date.today + days_from_now

      Rails.logger.info "Polling slots for #{date}..."

      # Fetch slots from Setmore for this date
      slots = client.fetch_slots(date)

      # Find which slots are new for this date
      new_slots = find_new_slots(date, slots)

      # If there are new slots, add them to our collection
      if new_slots.length > 0
        all_new_slots[date] = new_slots
        Rails.logger.info "Found #{new_slots.length} new slots for #{date}"
      end

      # Save all slots we saw this cycle to the database
      save_slots(date, slots)

      days_from_now = days_from_now + 1
    end

    # After checking all 7 days, send ONE combined text if anything is new
    if all_new_slots.length > 0
      notify_subscribers(all_new_slots)
    else
      Rails.logger.info "No new slots found across any day"
    end

    # Schedule this job to run again in 15 minutes
    PollSlotsJob.set(wait: 15.minutes).perform_later
    Rails.logger.info "PollSlotsJob complete. Next run in 15 minutes."
  end

  private

  def find_new_slots(date, slots)
    # Step 1 — filter out slots that have already passed
    future_slots = []
    slots.each do |slot|
      slot_datetime = parse_slot_datetime(date, slot)
      if slot_datetime > Time.now
        future_slots.push(slot)
      end
    end

    # Step 2 — find which future slots are brand new
    # A slot is new if it exists in Setmore but not in our database
    new_slots = []
    future_slots.each do |slot|
      slot_datetime = parse_slot_datetime(date, slot)
      already_exists = AvailableSlot.exists?(slot_datetime: slot_datetime)
      if already_exists == false
        new_slots.push(slot)
      end
    end

    new_slots
  end

  def save_slots(date, slots)
    # Filter to future slots only
    future_slots = []
    slots.each do |slot|
      slot_datetime = parse_slot_datetime(date, slot)
      if slot_datetime > Time.now
        future_slots.push(slot)
      end
    end

    # Save new slots to database
    future_slots.each do |slot|
      slot_datetime = parse_slot_datetime(date, slot)
      already_exists = AvailableSlot.exists?(slot_datetime: slot_datetime)
      if already_exists == false
        AvailableSlot.create(
          slot_datetime: slot_datetime,
          last_seen_at: Time.now
        )
      end
    end

    # Update last_seen_at for all slots we saw
    future_slots.each do |slot|
      slot_datetime = parse_slot_datetime(date, slot)
      available_slot = AvailableSlot.find_by(slot_datetime: slot_datetime)
      if available_slot != nil
        available_slot.update(last_seen_at: Time.now)
      end
    end
  end

  def notify_subscribers(all_new_slots)
    # Build one combined message covering all days with new slots
    message = "Automated message from karlblends: New timeslots open!\n\n"

    # Add one line per day
    all_new_slots.each do |date, slots|
      formatted_date = date.strftime("%A %b %-d")
      formatted_slots = slots.join(", ")
      message = message + "#{formatted_date}: #{formatted_slots}\n"
    end

    message = message + "\nBook: https://karlblends.setmore.com/"
    message = message + "\nReply STOP to opt out."

    # Get all active subscribers
    active_subscribers = Subscriber.active

    # Send one text to each subscriber
    active_subscribers.each do |subscriber|
      send_sms(subscriber.phone_number, message)
    end

    Rails.logger.info "Notified #{active_subscribers.count} subscribers"
  end

  def send_sms(to, message)
    # Create a Twilio client using credentials from .env
    client = Twilio::REST::Client.new(
      ENV["TWILIO_ACCOUNT_SID"],
      ENV["TWILIO_AUTH_TOKEN"]
    )

    # Send the SMS
    client.messages.create(
      from: ENV["TWILIO_PHONE_NUMBER"],
      to: to,
      body: message
    )

    Rails.logger.info "SMS sent to #{to}"
  rescue => e
    # If sending fails for one person, log it and continue
    # Don't let one failed SMS stop the rest from sending
    Rails.logger.error "Failed to send SMS to #{to}: #{e.message}"
  end

  # Combines a date and time string into one DateTime object
  # Example: date = 2026-06-26, slot = "1:00 PM"
  # Result: 2026-06-26 13:00:00
  def parse_slot_datetime(date, slot)
    Time.parse("#{date} #{slot}")
  end
end
