class Email < ApplicationRecord
  belongs_to :sent_by, class_name: 'User'
  
  has_rich_text :rich_content
  
  validates :subject, presence: true
  validates :rich_content, presence: true
  
  scope :sent, -> { where.not(sent_at: nil) }
  scope :draft, -> { where(sent_at: nil) }
  
  def sent?
    sent_at.present?
  end
  
  def draft?
    sent_at.blank?
  end
end
