# frozen_string_literal: true

# Loads the sqlite-vec extension for vector similarity search.
# This is the equivalent of what `rails generate neighbor:sqlite` produces.
module SqliteVecExtension
  def configure_connection
    super
    raw_connection.enable_load_extension(true)
    SqliteVec.load(raw_connection)
    raw_connection.enable_load_extension(false)
  end
end

ActiveSupport.on_load(:active_record) do
  require "sqlite_vec"
  ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SqliteVecExtension)
end
