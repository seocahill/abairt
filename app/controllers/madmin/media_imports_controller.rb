module Madmin
  class MediaImportsController < Madmin::ResourceController
    def import
      @media_import = MediaImport.find(params[:id])

      if @media_import.pending?
        @media_import.queue_for_processing!
        redirect_to main_app.madmin_media_import_path(@media_import), notice: "Import queued for processing"
      else
        redirect_to main_app.madmin_media_import_path(@media_import), alert: "MediaImport must be pending to import (current status: #{@media_import.status})"
      end
    end
  end
end
