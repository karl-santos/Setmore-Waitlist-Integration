class PollSlotsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "PollSlotsJob starting..."

    client = SetmoreClient.new

    # Loop through the next 7 days
    # days_from_now will be 0, 1, 2, 3, 4, 5, 6
    days_from_now = 0
    while days_from_now <= 6
      date = Date.today + days_from_now

      Rails.logger.info "Polling slots for #{date}..."

      # Fetch slots from Setmore for this date
      slots = client.fetch_slots(date)

      # Process the slots for this date
      process_slots(date, slots)

      days_from_now = days_from_now + 1
    end

    # Schedule this job to run again in 15 minutes
    PollSlotsJob.set(wait: 15.minutes).perform_later
    Rails.logger.info "PollSlotsJob complete. Next run in 15 minutes."
  end

  private

  def process_slots(date, slots)
    # Step 1 — filter out slots that have already passed today
    future_slots = []
    slots.each do |slot|
      slot_datetime = parse_slot_datetime(date, slot)
      if slot_datetime > Time.now
        future_slots.push(slot)
      end
    end

    # Step 2 — find which slots are brand new
    # A slot is new if it exists in Setmore but not in our database
    new_slots = []
    future_slots.each do |slot|
      slot_datetime = parse_slot_datetime(date, slot)
      already_exists = AvailableSlot.exists?(slot_datetime: slot_datetime)
      if already_exists == false
        new_slots.push(slot)
      end
    end

    # Step 3 — if we found new slots, notify subscribers
    if new_slots.length > 0
      Rails.logger.info "Found #{new_slots.length} new slots for #{date}"
      notify_subscribers(date, new_slots)

      # Save new slots to database so we don't notify about them again
      new_slots.each do |slot|
        slot_datetime = parse_slot_datetime(date, slot)
        AvailableSlot.create(
          slot_datetime: slot_datetime,
          last_seen_at: Time.now
        )
      end
    end

    # Step 4 — update last_seen_at for all slots we saw this cycle
    future_slots.each do |slot|
      slot_datetime = parse_slot_datetime(date, slot)
      available_slot = AvailableSlot.find_by(slot_datetime: slot_datetime)
      if available_slot != nil
        available_slot.update(last_seen_at: Time.now)
      end
    end
  end

  def notify_subscribers(date, new_slots)
    # Format the date nicely e.g. "Thursday Jun 26"
    formatted_date = date.strftime("%A %b %-d")

    # Format the slots nicely e.g. "1:00 PM, 1:40 PM"
    formatted_slots = new_slots.join(", ")

    # Build the SMS message
    message = "New slots just opened up \n\n"
    message = message + "#{formatted_date} — #{formatted_slots}\n\n"
    message = message + "Book now: https://book.setmore.com/scheduleappointment/YOUR_LINK_HERE\n\n"
    message = message + "Reply STOP to unsubscribe."

    # Get all active subscribers
    active_subscribers = Subscriber.active

    # Send a text to each one
    active_subscribers.each do |subscriber|
      send_sms(subscriber.phone_number, message)
    end

    Rails.logger.info "Notified #{active_subscribers.count} subscribers"
  end

  def send_sms(to, message)
    # Placeholder for now — we'll wire up Twilio next
    Rails.logger.info "SMS to #{to}: #{message}"
  end

  # Combines a date and time string into one DateTime object
  # Example: date = 2026-06-26, slot = "1:00 PM"
  # Result: 2026-06-26 13:00:00
  def parse_slot_datetime(date, slot)
    Time.parse("#{date} #{slot}")
  end
end
