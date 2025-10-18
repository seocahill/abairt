# Stores application-wide configuration settings as key-value pairs
#
# Usage:
#   Setting.set('fotheidil.refresh_token', 'abc123')
#   Setting.get('fotheidil.refresh_token') # => 'abc123'
#
class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  # Get a setting value by key
  def self.get(key)
    find_by(key: key)&.value
  end

  # Set a setting value by key
  def self.set(key, value)
    setting = find_or_initialize_by(key: key)
    setting.value = value
    setting.save!
    value
  end

  # Delete a setting by key
  def self.delete(key)
    find_by(key: key)&.destroy
  end
end
