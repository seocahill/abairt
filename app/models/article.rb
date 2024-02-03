class Article < ApplicationRecord
  belongs_to :user

  has_rich_text :content

  validates :title, presence: true

  alias_attribute :name, :title
  alias_attribute :description, :content
end
