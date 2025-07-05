class HomeController < ApplicationController
  skip_after_action :verify_authorized

  def index
    @pins = User.where(role: [:speaker, :teacher]).pins
    @tts_status = ServiceStatus.current_status('tts')
    @asr_status = ServiceStatus.current_status('asr')
    @pyannote_status = ServiceStatus.current_status('pyannote')
  end
end
