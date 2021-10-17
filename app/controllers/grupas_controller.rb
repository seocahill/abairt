class GrupasController < ApplicationController
  def index
    @grupai = Grupa.all
  end

  def show
    @grupa = Grupa.find(params[:id])
    records = Rang.where(grupa_id: params[:id])
    @pagy, @rangs = pagy(records)
  end
end
