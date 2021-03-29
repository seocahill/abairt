class Api::V1::DictionaryEntriesController < ApplicationController
  before_action :authenticate
  skip_before_action :verify_authenticity_token

  def create
    rang = Rang.where(user_id: current_user.id, url: params[:url]).first_or_create do |new_rang|
      new_rang.name = "Alt: #{params[:url]}"
    end
    if rang.dictionary_entries.create(word_or_phrase: params[:text], translation: params[:translation])
      head :ok
    else
      head :unprocessible_entity
    end
  end

  private

  def authenticate
    authenticate_or_request_with_http_token do |token, _options|
      User.find_by(token: token)
    end
  end

  def current_user
    @current_user ||= authenticate
  end
end
