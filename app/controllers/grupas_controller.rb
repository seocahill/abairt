class GrupasController < ApplicationController
  def index
    @grupai = Grupa.all
  end

  def show
    @grupa = Grupa.find(params[:id])
    records = Rang.where(grupa_id: params[:id])
    @pagy, @rangs = pagy(records)
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
        format.html { redirect_to @grupa, notice: 'Grupa was successfully created.' }
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

  def grupa_params
    params.require(:grupa).permit(:ainm)
  end
end
