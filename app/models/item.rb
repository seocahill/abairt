class Item < ApplicationRecord
  belongs_to :course
  belongs_to :itemable, polymorphic: true

  has_rich_text :description
  validates :name, :description, presence: true

  def next
    VoiceRecording.where("id > ?", id).first
  end

  def previous
    VoiceRecording.where("id < ?", id).last
  end
  class << self
    def search_itemables(query)
      WordList.where("name LIKE ?", "%#{query}%")
    end
  end
end
