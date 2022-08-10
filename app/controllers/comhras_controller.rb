class ComhrasController < ApplicationController
  before_action :set_comhra, only: %i[ show edit update destroy ]

  # GET /comhras or /comhras.json
  def index
    @comhras = Comhra.all.map { |c| c.slice(:id, :name, :lat_lang).merge(media_url: Rails.application.routes.url_helpers.rails_blob_url(c.media)) }
  end

  # GET /comhras/1 or /comhras/1.json
  def show
  end

  # GET /comhras/new
  def new
    @comhra = Comhra.new
  end

  # GET /comhras/1/edit
  def edit
  end

  # POST /comhras or /comhras.json
  def create
    @comhra = current_user.comhras.new(comhra_params)

    respond_to do |format|
      if @comhra.save
        format.html { redirect_to @comhra, notice: "Comhra was successfully created." }
        format.json { render :show, status: :created, location: @comhra }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @comhra.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /comhras/1 or /comhras/1.json
  def update
    respond_to do |format|
      if @comhra.update(comhra_params)
        format.html { redirect_to @comhra, notice: "Comhra was successfully updated." }
        format.json { render :show, status: :ok, location: @comhra }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @comhra.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /comhras/1 or /comhras/1.json
  def destroy
    @comhra.destroy
    respond_to do |format|
      format.html { redirect_to comhras_url, notice: "Comhra was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_comhra
      @comhra = Comhra.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def comhra_params
      params.fetch(:comhra).permit(:name, :user_id, :media, :grupa_id, :lat_lang)
    end
end
