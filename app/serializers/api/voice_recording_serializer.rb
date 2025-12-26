# frozen_string_literal: true

class Api::VoiceRecordingSerializer
  include Alba::Resource

  attributes :id, :title

  attribute :external_id, &:fotheidil_video_id
end

