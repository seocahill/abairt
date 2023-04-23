class HomeController < ApplicationController
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
end
