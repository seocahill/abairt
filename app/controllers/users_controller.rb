# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy]
  before_action :authorize, except: %i[index show]

  # GET /users or /users.json
  def index
    records = User.where.not(id: nil).teacher

    if params[:search].present?
      records = records.joins(:fts_users).where("fts_users match ?", params[:search]).distinct.order('rank')
    end

    @pins = User.where.not(lat_lang: nil).map do |g|
      g.slice(:id, :name, :lat_lang).tap do |c|
        if (sample = g.rangs.detect { |r| r.media.audio? }&.media)
          c[:media_url] = Rails.application.routes.url_helpers.rails_blob_url(sample)
        end
      end
    end

    @new_speaker = User.new

    @pagy, @users = pagy(records, items: 12)

    respond_to do |format|
      format.html
      format.json { render json: records }
    end
  end

  # GET /users/1 or /users/1.json
  def show
    @pagy, @entries = pagy(@user.dictionary_entries, items: 12)

    respond_to do |format|
      format.html
      format.csv { send_data @user.entries.to_csv, filename: "dictionary-#{Date.today}.csv" }
    end
  end

  # GET /users/new
  def new
    @user = User.new(role: :speaker)
  end

  # GET /users/1/edit
  def edit; end

  # POST /users or /users.json
  def create
    password = SecureRandom.uuid
    email = user_params[:email].present? ? user_params[:email] : user_params[:name].split.join + "@abairt.com"
    @user = User.new(user_params.merge(password: password, email: email, role: :speaker))

    respond_to do |format|
      if @user.save
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
    respond_to do |format|
      if @user.update(user_params)
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
    @user.destroy
    respond_to do |format|
      format.html { redirect_to users_url, notice: 'User was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  def authorize
    return if current_user && (current_user.id.to_s == params[:id].to_s)

    redirect_to root_path
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = User.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_params
    params.require(:user).permit(:email, :name, :password, :dialect, :voice, :lat_lang)
  end
end
