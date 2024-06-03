# frozen_string_literal: true

require "csv"

class DictionaryEntry < ApplicationRecord
  # only save new version if different user
  has_paper_trail only: [:word_or_phrase, :translation], if: Proc.new { |entry| Current.user&.id&.to_s != entry.versions.last&.whodunnit }, limit: 5, on: %i[update destroy]

  has_one_attached :media

  has_many :rang_entries, dependent: :destroy
  has_many :rangs, through: :rang_entries

  belongs_to :speaker, class_name: "User", foreign_key: "speaker_id", optional: true
  belongs_to :owner, class_name: "User", foreign_key: "user_id"

  has_many :fts_dictionary_entries, class_name: "FtsDictionaryEntry", foreign_key: "rowid"
  belongs_to :voice_recording, optional: true

  has_many :word_list_dictionary_entries, dependent: :destroy
  has_many :word_lists, through: :word_list_dictionary_entries

  has_many :learning_progresses, dependent: :destroy

  acts_as_taggable_on :tags

  accepts_nested_attributes_for :rang_entries

  scope :has_recording, -> { joins(:media_attachment) }

  validates :word_or_phrase, uniqueness: { case_sensitive: false }, allow_blank: true, unless: -> { voice_recording_id || speaker&.ai? || speaker&.student? }
  # Based on CEFR scale i.e. low: < B2, fair: B2, good: C, excellent: native
  enum quality: %i[
    low
    fair
    good
    excellent
  ]
  class << self
    def to_csv
      attributes = %w[word_or_phrase translation media_url]

      CSV.generate(headers: true) do |csv|
        csv << attributes

        all.find_each do |user|
          csv << attributes.map { |attr| user.send(attr) }
        end
      end
    end
  end

  def media_url
    return "" unless media.attached?

    Rails.application.routes.url_helpers.url_for(media)
  end

  def transcription?
    false
  end

  def create_audio_snippet
    require 'open3'

    return unless voice_recording_id

    # Select the region you want to extract
    duration = region_end - region_start

    # Set the output file path and delete cache
    output_path = "/tmp/#{region_id}.mp3"
    File.delete output_path rescue nil
    voice_recording.media.open do |file|
      if voice_recording.media.audio?
        # Extract the selected region and save it as a new MP3 file using ffmpeg
        stdout, stderr, status = Open3.capture3("ffmpeg -ss #{region_start} -i #{file.path} -t #{duration} -c:a copy #{output_path}")
      else
        stdout, stderr, status = Open3.capture3("ffmpeg -ss #{region_start} -i #{file.path} -t #{duration} -vn #{output_path}")
      end
      # Attach the new file to a Recording model using Active Storage
      self.media.attach(io: File.open(output_path), filename: "#{region_id}.mp3")
    end

    # Auto transcribe if no values
    return if word_or_phrase.present?

    self.word_or_phrase = transcribe_audio(output_path)
    save!
  end

  def chat_with_gpt(rang)
    # set default context
    context =  { role: 'system', content: "You are an Irish language learning coach who helps users learn and practice new languages. You always speak in the canúint of Mayo, that is the connacht dialect with a strong ulster influence. Offer grammar explanations, vocabulary building exercises, and pronunciation tips. You can speak in English if requested but try to return to Irish as quickly as possible. Engage users in conversations to help them improve their listening and speaking skills and gain confidence in using the language." }

    # send recent conversation with
    messages = rang.dictionary_entries.last(10).map do |message|
      if message.speaker.ai?
        { role: "assistant", content: message.word_or_phrase }
      else
        { role: "user", content: message.word_or_phrase }
      end
    end
    # context first and last
    messages.unshift(context)
    Rails.logger.debug(messages)
    # generate chat
    response = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)).chat(parameters: {
        model: 'gpt-4o',
        messages: messages,
        temperature: 0.5
      })
    Rails.logger.debug response
    response.dig('choices', 0, 'message', 'content')
  rescue => e
    Rails.logger.debug(e)
    "Tá aiféala orm ach tá ganntanas airgid ag cur isteach orm. Tá mo OpenAI cúntas folamh, is dóigh liom."
  end

  def create_ai_response(rang)
    ChatBotJob.perform_later(self, rang)
  end

  def auto_tag
    client = OpenAI::Client.new(access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org))

    prompt = "Please analyze the following phrase and generate tags with a focus on grammatical features, broader semantic categories relevant to language learners and also a mood. Keep the selected categories general and not too granular. Return up to two category tags, a single grammatical feature tag and a single mood or voice tag, the most relevant of each in your opinion. The results you return should be a single array of the tags you have chose, nothing else. Phrase: #{translation}"

    response = client.chat(parameters: {
      model: "gpt-4o",  # or use the appropriate model you have access to
      messages: [
        { "role": "user", "content": prompt }
      ]
    })
    self.tag_list = JSON.parse(response.dig('choices', 0, 'message', 'content'))
    save
  end

  def transcribe_audio(file_path, content_type = 'mp3')
    audio_blob = `ffmpeg -i "#{file_path}" -f wav -acodec pcm_s16le -ac 1 -ar 16000 - | base64`
    uri = URI.parse('https://phoneticsrv3.lcs.tcd.ie/asr_api/recognise')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path)

    payload = {
      recogniseBlob: audio_blob,
      developer: true,
      method: 'online2bin'
    }

    request.body = payload.to_json
    request['Content-Type'] = 'application/json'

    response = http.request(request)
    Rails.logger.debug(response)
    JSON.parse(response.body).dig("transcriptions", 0, "utterance")
  rescue => e
    "trasscríobh ar bith"
  end


  def synthesize_text_to_speech_and_store
    uri = URI.parse('https://abair.ie/api2/synthesise')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path)
    request.body = {
      synthinput: { text: word_or_phrase, ssml: 'string' },
      voiceparams: { languageCode: 'ga-IE', name: 'ga_UL_anb_nemo', ssmlGender: 'UNSPECIFIED' },
      audioconfig: { audioEncoding: 'LINEAR16', speakingRate: 1, pitch: 1, volumeGainDb: 1 },
      outputType: 'JSON'
    }.to_json
    request['Content-Type'] = 'application/json'
    response = http.request(request)
    api_response = JSON.parse(response.body)
    decoded_data = Base64.decode64(api_response['audioContent'])

    # Create a temporary file and attach to ActiveStorage within its block
    Tempfile.create(['temp_audio', '.wav']) do |temp_file|
      temp_file.binmode
      temp_file.write(decoded_data)
      temp_file.rewind
      self.media.attach(io: temp_file, filename: 'chat.wav', content_type: 'audio/wav')
    end
  end
end
