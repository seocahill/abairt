class Course < ApplicationRecord
  belongs_to :user
  has_many :items, dependent: :destroy

  has_rich_text :description

  validates :name, presence: true
end
