class GrupasController < ApplicationController
  before_action :authorize, except: %i[index show]

  def index
    @grupai = Grupa.all
    @pins = @grupai.where.not(lat_lang: nil).joins(:rangs).map do |g|
      g.slice(:id, :ainm, :lat_lang).tap do |c|
        if (sample = g.rangs.detect { |r| r.media.audio? }&.media)
          c[:media_url] = Rails.application.routes.url_helpers.rails_blob_url(sample)
        end
      end
    end
  end

  def show
    @grupa = Grupa.find(params[:id])
    records = Rang.where(grupa_id: params[:id])
    @pagy, @rangs = pagy(records)
  end

  def new
    @grupa = Grupa.new
  end

  # GET /Grupas/1/edit
  def edit
    @grupa = Grupa.find(params[:id])
  end

  # POST /Grupas or /Grupas.json
  def create
    @Grupa = Grupa.new(grupa_params)

    respond_to do |format|
      if @Grupa.save
        format.html { redirect_back(fallback_location: grupas_path, info: "Tá an jab déanta") }
        format.json { render :show, status: :created, location: @grupa }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @grupa.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @grupa = Grupa.find(params[:id])
    respond_to do |format|
      if @grupa.update(grupa_params)
        format.html { redirect_to @grupa, notice: 'grupa was successfully updated.' }
        format.json { render :show, status: :ok, location: @grupa }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @grupa.errors, status: :unprocessable_entity }
      end
    end
  end

  def scrios_dalta
    user = User.find(params[:user_id])
    user.grupa_id = nil
    user.save!

    redirect_back(fallback_location: grupas_path, info: "Tá an jab déanta")
  end

  def dalta_nua
    grupa = Grupa.find(params[:grupa_id])

    user = User.where(email: params[:email]).first_or_create do |new_user|
      new_user.password = SecureRandom.alphanumeric
    end

    grupa.users << user

    redirect_to edit_grupa_path(grupa), info: "Dalta nua curtha leis"
  end

  def grupa_params
    params.require(:grupa).permit(:ainm, :lat_lang)
  end

  private

  def authorize
    return if current_user

    redirect_back(fallback_location: root_path, alert: "Tá ort a bheith sínithe isteach!")
  end
end
