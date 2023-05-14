class UserList < ApplicationRecord
  belongs_to :user
  belongs_to :word_list
end
