class GrupasController < ApplicationController
  before_action :authorize, except: %i[index show]

  def index
    @pagy, @files = pagy(ActiveStorage::Attachment.where(record_type: "Rang"), items: PAGE_SIZE)
    @rang = Rang.with_attached_media.find(56)
    @regions = @rang.dictionary_entries.map { |e| e.slice(:region_id, :region_start, :region_end, :word_or_phrase)}.to_json
    @tags = ActsAsTaggableOn::Tag.most_used(15)
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
    @grupa = Grupa.new(grupa_params)
    @grupa.muinteoir = current_user
    respond_to do |format|
      if @grupa.save
        format.html { redirect_to @grupa }
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
