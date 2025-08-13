class AddBackupCodesToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :backup_codes_hashes, :text
    add_column :users, :backup_codes_salt, :string
    add_column :users, :backup_codes_generated_at, :datetime
    add_index :users, :backup_codes_generated_at
  end
end
