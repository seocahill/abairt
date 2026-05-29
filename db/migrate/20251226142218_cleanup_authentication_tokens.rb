class CleanupAuthenticationTokens < ActiveRecord::Migration[8.1]
  def up
    # Rename password_reset_token to login_token
    rename_column :users, :password_reset_token, :login_token if column_exists?(:users, :password_reset_token)
    
    # Remove password_digest (not needed for passwordless auth)
    remove_column :users, :password_digest if column_exists?(:users, :password_digest)
    
    # Remove password_reset_sent_at (use updated_at instead)
    remove_column :users, :password_reset_sent_at if column_exists?(:users, :password_reset_sent_at)
  end

  def down
    add_column :users, :password_digest, :string if !column_exists?(:users, :password_digest)
    add_column :users, :password_reset_sent_at, :datetime if !column_exists?(:users, :password_reset_sent_at)
    rename_column :users, :login_token, :password_reset_token if column_exists?(:users, :login_token)
  end
end
