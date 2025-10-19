class MediaImportResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :url
  attribute :title
  attribute :headline
  attribute :description
  attribute :status
  attribute :error_message
  attribute :imported_at
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations

  # Custom actions
  member_action do
    if @record.pending?
      button_to "Import",
                main_app.import_madmin_media_import_path(@record),
                method: :post,
                data: { turbo_confirm: "Are you sure you want to import this media?" },
                class: "block bg-blue-500 hover:bg-blue-600 text-white font-semibold py-2 px-4 border border-blue-600 rounded shadow"
    end
  end
end
