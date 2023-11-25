# frozen_string_literal: true

class RangsController < ApplicationController
  before_action :set_rang, only: %i[show edit update destroy]
  after_action :verify_authorized

  # GET /rangs or /rangs.json
  def index
    authorize(Rang)

    @current_user = current_user
    @rangs = (current_user.lectures + current_user.rangs).uniq
    @students = User.student
  end

  # GET /rangs/1 or /rangs/1.json
  def show
    @rang = Rang.find(params[:id])
    authorize(@rang)

    @current_user = current_user
    @muinteoir = @rang.teacher
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

  # GET /rangs/new
  def new
    @rang = Rang.new(name: "Cómhrá #{Date.today.to_fs(:short)}")
    authorize @rang
    @student = @rang.users.build(password: SecureRandom.alphanumeric)
    @students = @rang.users
    @users = User.student.where.not(id: @students.ids)
  end

  # GET /rangs/1/edit
  def edit
    authorize @rang
    # @rang.users.build(password: SecureRandom.alphanumeric)
    @students = @rang.users
    @users = User.student.where.not(id: @students.ids)
  end

  # POST /rangs or /rangs.json
  def create
    @rang = Rang.new(rang_params.merge(user_id: current_user.id))
    authorize @rang

    respond_to do |format|
      if @rang.save
        format.html { redirect_to rangs_path, notice: 'Rang was successfully created.' }
        format.json { render :show, status: :created, location: @rang }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @rang.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /rangs/1 or /rangs/1.json
  def update
    authorize @rang
    @students = @rang.users
    @users = User.student.where.not(id: @students.ids)

    if params.dig("rang", "user_ids") && ! params["delete"]
      params["rang"]["user_ids"] += @rang.users.ids.map(&:to_s)
    end

    respond_to do |format|
      @rang.assign_attributes(rang_params)

      if @rang.save
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            @rang,
            partial: "rangs/form",
            locals: { rang: @rang, current_user: current_user, students: @students, users: @users }
          )
        end
        format.html { redirect_to rangs_path(chat: @rang.id), notice: 'Rang was successfully updated.' }
        format.json { render :show, status: :ok, location: @rang }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @rang.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /rangs/1 or /rangs/1.json
  def destroy
    authorize @rang
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
    params.require(:rang).permit(:name, :user_id, :context, users_attributes: [:email, :password, :name], user_ids: [], seomras_attributes: [:user_id, :rang_id])
  end

end
