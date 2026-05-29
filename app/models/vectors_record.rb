# frozen_string_literal: true

# Base class for models stored in the vectors database
class VectorsRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :vectors, reading: :vectors }
end
