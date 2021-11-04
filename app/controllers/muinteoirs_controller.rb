class MuinteoirsController < ApplicationController
  def show
    @user = User.find(params[:id])
    start_date = params.fetch(:start_date, Date.today).to_date
    groups =
    @rangs = current_user.muinteoir_rangs.or(current_user.rangs)
  end

  def index
    @users = User.where(master_id: nil)
  end
end
