class LearningProgress < ApplicationRecord
  belongs_to :learning_session
  belongs_to :dictionary_entry
end
