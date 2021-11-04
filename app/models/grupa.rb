class Grupa < ApplicationRecord
  belongs_to :muinteoir, class_name: 'User', foreign_key: :muinteoir_id, optional: true
  has_many :rangs
  has_many :users
end
