# frozen_string_literal: true

Pub = Struct.new(:name, :lat_lang, :url)

class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy]

  # GET /users or /users.json
  def index
    @template = "user"
    records = User.where.where(ability: %i[C1 C2 native]).where.not(id: nil)

    if params[:search].present?
      # records = records.joins(:fts_users).where("fts_users match ?", params[:search]).distinct.order('rank')
      records = User.where("name LIKE ?", "%#{params[:search]}%")
    end

    if params[:dialect].present?
      value =  User.dialects[params[:dialect]]
      records = User.where("users.dialect = ?", value)
    end

    @showmap = params[:map]

    @pins = User.where(ability: %i[C1 C2 native]).where.not(lat_lang: nil).map do |g|
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
      format.json { render json: records }
    end
  end

  # GET /users/1 or /users/1.json
  def show
    @pagy, @entries = pagy(@user.dictionary_entries, items: PAGE_SIZE)
    @starred = current_user&.starred
    @new_speaker = User.new
    @template = "profile"

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
      if @user.save!
        format.html { redirect_to @user, notice: 'User was successfully created.' }
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
    params.require(:user).permit(:email, :name, :password, :dialect, :voice, :lat_lang, :role, :address, :about, :ability)
  end
end
