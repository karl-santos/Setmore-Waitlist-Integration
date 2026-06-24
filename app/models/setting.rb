class Setting < ApplicationRecord
  def self.get_access_token
    setting = first          # grab the first (and only) row
    return nil if setting.nil?  # if no row exists yet, return nil
    setting.access_token     # otherwise return the token
  end

  # saves a new access token to the database
  # get the existing row, or create one if none exists
  def self.store_token(token, expires_in)
    setting = first_or_create
    setting.update(
      access_token: token,
      # expires_in comes from Setmore as a number of seconds (7199)
      # we add that to the current time to get the exact expiry datetime
      token_expires_at: Time.now + expires_in.seconds
    )
  end

  # Returns true if the token exists and won't expire in the next 10 minutes
  # Returns false if there's no token or it's expiring soon
  # We call this before every poll cycle to decide whether to refresh
  def self.token_valid?
    setting = first
    return false if setting.nil?              # no row = no token = not valid
    return false if setting.access_token.nil? # no token stored = not valid
    # check if expiry is more than 10 minutes away
    setting.token_expires_at > Time.now + 10.minutes
  end
end
