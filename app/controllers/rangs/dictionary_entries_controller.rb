class Rangs::DictionaryEntriesController < ApplicationController
  # POST /dictionary_entries or /dictionary_entries.json
  before_action :authorize

  def create
    @dictionary_entry = DictionaryEntry.new(dictionary_entry_params.merge(speaker_id: current_user.id))

    respond_to do |format|
      if @dictionary_entry.save
        broadcast_to_rang
        format.html
        # format.turbo_stream
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  private

  def broadcast_to_rang
    Turbo::StreamsChannel.broadcast_append_to("rangs",
                                            target: "paginate_page_#{params[:page]}",
                                            partial: "rangs/message",
                                            locals: {message: @dictionary_entry, current_user: current_user, current_day: @dictionary_entry.updated_at.strftime("%d-%m-%y") })
  end

  def set_rang
    return unless params[:rang_id]

    @rang = Rang.find(params[:rang_id])
  end

  # Only allow a list of trusted parameters through.
  def dictionary_entry_params
    params.require(:dictionary_entry).permit(:word_or_phrase, :translation, :notes, :media, :tag_list, :speaker_id, rang_ids: [])
  end
end
