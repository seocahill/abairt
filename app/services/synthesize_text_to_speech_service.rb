# frozen_string_literal: true

# Uses the Abair API to synthesize text to speech

class SynthesizeTextToSpeechService
  def initialize(entry)
    @entry = entry
  end

  def process
    uri = URI.parse("https://api.abair.ie/v3/synthesis")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path)
    request.body = {
      synthinput: {text: @entry.word_or_phrase, ssml: "string"},
      voiceparams: {languageCode: "ga-IE", name: "ga_UL_anb_piper", ssmlGender: "UNSPECIFIED"},
      audioconfig: {
        audioEncoding: "LINEAR16",
        speakingRate: 1,
        pitch: 1,
        volumeGainDb: 1,
        htsParams: "string",
        sampleRateHertz: 0,
        effectsProfileId: []
      },
      outputType: "JSON"
    }.to_json
    request["Content-Type"] = "application/json"
    response = http.request(request)
    api_response = JSON.parse(response.body)
    decoded_data = Base64.decode64(api_response["audioContent"])

    attach(decoded_data) if @entry.persisted?

    api_response["audioContent"]
  end

  private

  # Attach without saving the entry, so its validations (uniqueness,
  # confirmed entries) can't leave the attachment unsaved.
  def attach(audio)
    ActiveStorage::Attachment.transaction do
      @entry.lock!
      next if @entry.media.attached?

      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(audio), filename: "chat.wav", content_type: "audio/wav")
      ActiveStorage::Attachment.create!(name: "media", record: @entry, blob: blob)
    end
    @entry.reload
  end
end
