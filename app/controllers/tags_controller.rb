class TagsController < ApplicationController
  def index
    records = Tag.all

    if params[:search].present?
      records = records.joins(:fts_tags).where("fts_tags match ?", params[:search]).distinct.order('rank')
    end

    render json: records
  end
end
