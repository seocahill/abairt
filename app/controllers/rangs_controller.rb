# frozen_string_literal: true

class RangsController < ApplicationController
  before_action :set_rang, only: %i[show edit update destroy]
  before_action :authorize
  # layout "chat"

  # GET /rangs or /rangs.json
  def index
    @current_user = current_user
    @rangs = current_user.lectures + current_user.rangs
    #FIXME
    @rang = params[:chat] ? Rang.find(params[:chat]) : @rangs.first


    records = @rang.dictionary_entries.where.not(id: nil).order(:updated_at)
    per_page = 20

    if params[:page].present?
      current_page_number = params[:page].to_i
    else
      current_page_number = Pagy.new(count: records.size, items: per_page).last
    end

    @pagy, @messages = pagy(records, items: per_page, page: current_page_number)

    if current_user
      @new_dictionary_entry = @rang.dictionary_entries.build(speaker_id: current_user.id)
    end
  end

  # GET /rangs/1 or /rangs/1.json
  def show
    @muinteoir = @rang.teacher
    @regions = @rang.dictionary_entries.map { |e| e.slice(:region_id, :region_start, :region_end, :word_or_phrase, :translation)}.to_json
  end

  # GET /rangs/new
  def new
    @rang = Rang.new(name: "Cómhrá #{Date.today.to_s(:short)}")
    @student = @rang.users.build(password: SecureRandom.uuid)
  end

  # GET /rangs/1/edit
  def edit; end

  # POST /rangs or /rangs.json
  def create
    @rang = Rang.new(rang_params.merge(user_id: current_user.id))

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

      if @rang.save
        @rang.send_notification
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
    params.require(:rang).permit(:name, :user_id, users_attributes: [:email, :password])
  end

  def authorize
    return if current_user

    redirect_back(fallback_location: root_path, alert: "Caithfidh tú a bheith sínithe isteach!")
  end
end
