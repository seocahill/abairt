# frozen_string_literal: true

module CsvExportable
  extend ActiveSupport::Concern

  class_methods do
    def to_csv(exclude_columns: [])
      # Get all column names from the model
      attributes = self.column_names

      # Filter out any excluded columns
      attributes = attributes - exclude_columns.map(&:to_s) if exclude_columns.present?

      CSV.generate(headers: true) do |csv|
        csv << attributes

        all.find_each do |record|
          csv << attributes.map { |attr| record.send(attr) }
        end
      end
    end
  end
end
