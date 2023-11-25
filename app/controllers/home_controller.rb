class HomeController < ApplicationController
  skip_after_action :verify_authorized

  def index
    @pins = User.where(role: [:speaker, :teacher]).pins
  end
end
