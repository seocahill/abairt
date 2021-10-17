# frozen_string_literal: true

class RangsController < ApplicationController
  before_action :set_rang, only: %i[show edit update destroy]
  before_action :authorize, except: %i[show index]

  # GET /rangs or /rangs.json
  def index
    records = Rang.all
    @pagy, @rangs = pagy(records)
  end

  # GET /rangs/1 or /rangs/1.json
  def show; end

  # GET /rangs/new
  def new
    @rang = Rang.new
  end

  # GET /rangs/1/edit
  def edit; end

  # POST /rangs or /rangs.json
  def create
    @rang = Rang.new(rang_params.merge(user_id: current_user.id))

    respond_to do |format|
      if @rang.save
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
      if @rang.update(rang_params)
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

    redirect_to root_path
  end
end
