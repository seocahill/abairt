# frozen_string_literal: true

module Admin
  class MediaImportsController < ApplicationController
    include Pagy::Backend

    before_action :ensure_admin
    before_action :set_media_import, only: [:show, :edit, :update, :destroy, :process_now, :retry]
    skip_after_action :verify_authorized

    def index
      scope = MediaImport.order(created_at: :desc)
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where("title ILIKE ? OR url ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?

      @pagy, @media_imports = pagy(scope, items: 25)

      @stats = {
        total: MediaImport.count,
        pending: MediaImport.pending.count,
        imported: MediaImport.imported.count,
        skipped: MediaImport.skipped.count,
        failed: MediaImport.where(status: :failed).count
      }
    end

    def show
    end

    def new
      @media_import = MediaImport.new
    end

    def create
      @media_import = MediaImport.new(media_import_params)

      if @media_import.save
        redirect_to admin_media_imports_path, notice: "Media import created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @media_import.update(media_import_params)
        redirect_to admin_media_imports_path, notice: "Media import updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @media_import.destroy
      redirect_to admin_media_imports_path, notice: "Media import deleted."
    end

    def process_now
      @media_import.queue_for_processing!
      redirect_to admin_media_imports_path, notice: "Queued #{@media_import.title} for processing."
    end

    def retry
      @media_import.update(status: :pending, error_message: nil)
      @media_import.queue_for_processing!
      redirect_to admin_media_imports_path, notice: "Retrying #{@media_import.title}."
    end

    def process_all_pending
      count = MediaImport.pending.count
      MediaImport.queue_all_pending!
      redirect_to admin_media_imports_path, notice: "Queued #{count} pending imports for processing."
    end

    private

    def set_media_import
      @media_import = MediaImport.find(params[:id])
    end

    def media_import_params
      params.require(:media_import).permit(:url, :title, :headline, :description, :status)
    end
  end
end
