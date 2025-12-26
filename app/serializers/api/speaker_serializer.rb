# frozen_string_literal: true

class Api::SpeakerSerializer
  include Alba::Resource

  attributes :id, :name, :dialect
end

