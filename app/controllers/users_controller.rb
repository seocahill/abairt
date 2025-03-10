# frozen_string_literal: true

Pub = Struct.new(:name, :lat_lang, :url)

class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy]
  # before_action :authenticate_user!, except: [:index, :show]

  # GET /users or /users.json
  def index
    # authorize current_user
    @template_name = "user"
    records = policy_scope(User).speaker

    if params[:search].present?
      records = records.where("LOWER(name) LIKE ?", "%#{params[:search].downcase}%")
    end

    if params[:dialect].present?
      value = User.dialects[params[:dialect]]
      records = records.where(dialect: value)
    end

    # Get pins for all qualifying users regardless of pagination
    @pins = records
                  .where.not(lat_lang: nil)
                  .map do |g|
      g.slice(:id, :name, :lat_lang).tap do |c|
        if (sample = g.dictionary_entries.detect { |d| d.media&.audio? }&.media)
          c[:media_url] = Rails.application.routes.url_helpers.rails_blob_url(sample)
        end
      end
    end

    @pubs = User.place.where.not(lat_lang: nil).map do |g|
      g.slice(:id, :name, :lat_lang).tap do |c|
        c[:url] = g.about
      end
    end

    if current_user&.edit?
      @new_speaker = User.new(role: :speaker)
    end

    @pagy, @users = pagy(records, items: PAGE_SIZE)

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { render json: records }
    end
  end

  # GET /users/1 or /users/1.json
  def show
    authorize current_user
    @pagy, @entries = pagy(@user.all_entries, items: PAGE_SIZE)
    @starred = current_user&.starred
    @new_speaker = User.new
    @template_name = "profile"
    @pagy_users, @pending_users = pagy(User.student.where.not(confirmed: true), items: 5)

    respond_to do |format|
      format.html
      format.csv { send_data @user.entries.to_csv, filename: "dictionary-#{Date.today}.csv" }
    end
  end

  # GET /users/new
  def new
    authorize(current_user)
    @user = User.new
  end

  # GET /users/1/edit
  def edit
    authorize current_user
  end

  # POST /users or /users.json
  def create
    authorize current_user
    @user = User.new(user_params.merge(password: SecureRandom.uuid))

    respond_to do |format|
      if @user.save
        if params[:user][:replace_speaker_id].present?
          temp_speaker = User.find(params[:user][:replace_speaker_id])
          voice_recording = temp_speaker.spoken_voice_recordings.first
          DictionaryEntry.transaction do
            DictionaryEntry.where(speaker: temp_speaker)
                         .update_all(speaker_id: @user.id)
          end

          format.html { redirect_to voice_recording_speakers_path(voice_recording), notice: "Speaker was successfully created and entries transferred." }
        else
          format.html { redirect_to @user, notice: "Speaker was successfully created." }
        end
        format.json { render :show, status: :created, location: @user }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /users/1 or /users/1.json
  def update
    authorize current_user

    respond_to do |format|
      if @user.update(user_params)
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            @user,
            partial: params["partial"],
            locals: { user: @user, current_user: current_user }
          )
        end
        format.html { redirect_to @user, notice: 'User was successfully updated.' }
        format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1 or /users/1.json
  def destroy
    authorize current_user
    # FIXME implement soft delete
    # render head :ok
    # @user.destroy
    respond_to do |format|
      format.html { redirect_to users_url, notice: 'User was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  def pub_list
    [
      Pub.new("Teach Chonghóile", "54.313123,-9.8230029", "https://goo.gl/maps/cGVh3FmjhVvCyLQt6"),
      Pub.new("Máire Lukes", "53.6128147,-9.4194681", "https://goo.gl/maps/e5FvZnm8RnkJGyDi8"),
      Pub.new("The Compass", "53.8767457,-9.9279619", "https://goo.gl/maps/Q9BS13btgPt7j8b79"),
      Pub.new("Turas Siar", "54.1274471,-10.0904116", "https://goo.gl/maps/ojSnzBFiyL3rGcqy9")
    ]

  end

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :role, :dialect, :voice, :lat_lang, :address, :ability)
  end
end
