# frozen_string_literal: true

class TranslatorLeaderboardController < ApplicationController
  skip_after_action :verify_authorized
  
  def index
    @translators = User.joins("JOIN dictionary_entries ON dictionary_entries.translator_id = users.id")
                       .where.not(role: [:temporary, :ai])
                       .group('users.id')
                       .select('users.*, COUNT(dictionary_entries.id) as translation_count')
                       .order('translation_count DESC')
                       .having('COUNT(dictionary_entries.id) > 0')
  end
end