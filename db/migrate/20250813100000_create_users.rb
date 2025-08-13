class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.string :password_salt, null: false
      t.string :password_hash, null: false
      t.integer :password_iterations, null: false, default: 120_000

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
