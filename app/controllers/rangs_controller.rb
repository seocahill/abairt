# frozen_string_literal: true

class RangsController < ApplicationController
  before_action :set_rang, only: %i[show edit update destroy]
  before_action :authorize, except: %i[show index]
  # layout "chat"

  # GET /rangs or /rangs.json
  def index
    @contacts = current_user.rangs
    @contact = Rang.find(2)
    @page = params[:page] || 1
    records = @contact.dictionary_entries.where.not(id: nil).order(:updated_at)
    @pagy, @messages = pagy(records, items: 10, page: params[:page])

    if current_user
      @new_dictionary_entry = @contact.dictionary_entries.build(speaker_id: current_user.id)
    end
  end

  # GET /rangs/1 or /rangs/1.json
  def show
    @muinteoir = @rang.grupa.muinteoir
    @regions = @rang.dictionary_entries.map { |e| e.slice(:region_id, :region_start, :region_end, :word_or_phrase, :translation)}.to_json
  end

  # GET /rangs/new
  def new
    @rang = Rang.new(name: "Cómhrá #{Date.today.to_s(:short)}")
  end

  # GET /rangs/1/edit
  def edit; end

  # POST /rangs or /rangs.json
  def create
    @rang = Rang.new(rang_params.merge(user_id: current_user.id))

    if @rang.name.blank? && @rang.grupa_id.present?
      @rang.name = [@rang.grupa.ainm, @rang.time.to_s(:short)].join("-")
    end

    if @rang.start_time.nil?
      @rang.start_time = @rang.time
    end

    if @rang.end_time.nil?
      @rang.end_time = @rang.time + 1.hour
    end

    respond_to do |format|
      if @rang.save
        @rang.send_notification
        format.html { redirect_to @rang, notice: 'Rang was successfully created.' }
        format.json { render :show, status: :created, location: @rang }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @rang.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /rangs/1 or /rangs/1.json
  def update
    respond_to do |format|
      @rang.assign_attributes(rang_params)

      if @rang.time_changed?
        @rang.start_time = @rang.time
        @rang.end_time = @rang.time + 1.hour
      end

      if @rang.save
        @rang.send_notification unless @rang.media.audio?
        format.html { redirect_to @rang, notice: 'Rang was successfully updated.' }
        format.json { render :show, status: :ok, location: @rang }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @rang.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /rangs/1 or /rangs/1.json
  def destroy
    @rang.destroy
    respond_to do |format|
      format.html { redirect_to rangs_url, notice: 'Rang was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_rang
    @rang = Rang.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def rang_params
    params.require(:rang).permit(:name, :user_id, :media, :time, :grupa_id)
  end

  def authorize
    return if current_user

    redirect_back(fallback_location: root_path, alert: "Tá ort a bheith sínithe isteach!")
  end
end
