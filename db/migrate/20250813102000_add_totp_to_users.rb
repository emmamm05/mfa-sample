class AddTotpToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :totp_secret, :string
    add_column :users, :totp_enabled_at, :datetime
    add_index :users, :totp_enabled_at
  end
end
