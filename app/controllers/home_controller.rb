class HomeController < ApplicationController
  def index
    @pins = User.where(role: [:speaker, :teacher]).pins
  end
end
