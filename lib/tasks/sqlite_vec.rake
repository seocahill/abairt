# frozen_string_literal: true

# Rails' `db:test:prepare` loads structure.sql via the system `sqlite3` CLI,
# which on macOS has extension loading disabled. This patches the SQLite
# structure load to use the raw connection's execute_batch instead (which has
# vec0 loaded via the initializer), so virtual tables like vec0 work.
module SqliteVecStructureLoad
  def structure_load(filename, extra_flags = nil)
    sql = File.read(filename)
    ActiveRecord::Base.connection.raw_connection.execute_batch(sql)
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Tasks::SQLiteDatabaseTasks.prepend(SqliteVecStructureLoad)
end
