class SetmoreClient
  BASE_URL = "https://developer.setmore.com/api/v1"
  SERVICE_KEY = "51f23d45-9f90-41ce-9b4c-75d562b9f122" # Haircut $25
  STAFF_KEY = "ct7xubSDh4ZQTwCJhpoqUK6hPaxmbaic"

  # Fetch slots for a given date
  # Takes a Ruby Date object
  # Returns an array of time strings e.g. ["12:20 PM", "1:00 PM"]
  def fetch_slots(date)
    ensure_valid_token
    fetch_slots_for_service(date) # Fetch and return slots for the one service
  end

  private

  # Checks if token is valid, refreshes if not
  def ensure_valid_token
    unless Setting.token_valid?
      refresh_token!
    end
  end

  # Exchanges refresh token for a new access token
  # Stores it in the settings table
  def refresh_token!
    refresh_token = ENV["SETMORE_REFRESH_TOKEN"]

    response = HTTParty.get(
      "#{BASE_URL}/o/oauth2/token",
      query: { refreshToken: refresh_token }
    )

    body = response.parsed_response

    if body["response"] == true
      token = body["data"]["token"]["access_token"]
      expires_in = body["data"]["token"]["expires_in"]
      Setting.store_token(token, expires_in)
    else
      raise "Setmore token refresh failed: #{body["msg"]}"
    end
  end

  # Fetches slots from Setmore for a given date
  # Returns array of time strings, or empty array if none available
  def fetch_slots_for_service(date)
    # Setmore expects DD/MM/YYYY format
    formatted_date = date.strftime("%d/%m/%Y")

    response = HTTParty.post(
      "#{BASE_URL}/bookingapi/slots",
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{Setting.get_access_token}"
      },
      body: {
        staff_key: STAFF_KEY,
        service_key: SERVICE_KEY,
        selected_date: formatted_date,
        slot_limit: 40
      }.to_json
    )

    body = response.parsed_response

    # Token expired mid-cycle — refresh and retry once
    if body["response"] == false && body["error"] == "unauthorized_request"
      refresh_token!
      return fetch_slots_for_service(date)
    end

    # Any other failure — log and return empty array
    # Don't crash the whole poll cycle over one bad response
    if body["response"] == false
      Rails.logger.error("Setmore slots error: #{body["msg"]}")
      return []
    end

    # Success — return slots array
    body["data"]["slots"]
  end
end
