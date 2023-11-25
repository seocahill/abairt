class ReifiesController < ApplicationController
  def create
    version = PaperTrail::Version.find(params[:version_id])
    item = version.reify
    if authorize(item) && item.save
      redirect_to item, notice: "Successfully reified"
    else
      redirect_to root_path, alert: "Could not reify version"
    end
  end
end
