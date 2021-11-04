class MuinteoirsController < ApplicationController
  def show
    @user = User.find(params[:id])
    start_date = params.fetch(:start_date, Date.today).to_date
    @rangs = @user.muinteoir_rangs.or(@user.rangs)
  end

  def index
    @users = User.joins(:muinteoir_grupas).distinct
  end
end
