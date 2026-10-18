# frozen_string_literal: true

class CreateMinecraftServers < ActiveRecord::Migration[7.0]
  def change
    create_table :minecraft_servers do |t|
      t.integer :user_id, null: false
      t.string :name, null: false, limit: 80
      t.string :address, null: false, limit: 320
      t.string :host, null: false, limit: 253
      t.integer :port, null: false, default: 25_565
      t.string :description, null: false, default: "", limit: 1000
      t.string :status, null: false, default: "pending", limit: 20
      t.boolean :listed, null: false, default: false
      t.boolean :online, null: false, default: false
      t.integer :players_online, null: false, default: 0
      t.integer :players_max, null: false, default: 0
      t.string :version_name, limit: 80
      t.string :motd, limit: 500
      t.text :favicon
      t.integer :latency_ms
      t.datetime :checked_at
      t.datetime :approved_at
      t.datetime :last_submitted_at
      t.string :last_error, limit: 500
      t.timestamps
    end

    add_index :minecraft_servers, :user_id
    add_index :minecraft_servers, [:host, :port], unique: true
    add_index :minecraft_servers, [:listed, :online]
    add_index :minecraft_servers, :status
  end
end