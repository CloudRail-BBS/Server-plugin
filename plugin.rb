# frozen_string_literal: true

# name: minecraft-server-directory
# about: A moderated Minecraft server directory with live Java Edition status probes.
# version: 1.0.0
# authors: CloudRail BBS
# url: https://github.com/CloudRail-BBS/Server-plugin
# required_version: 3.2.0
# transpile_js: true

# The installed directory and PLUGIN_NAME must both be `minecraft-server-directory`.
# The Git repository is Server-plugin, but Discourse derives stylesheet URLs from
# the directory, and core only accepts lowercase letters, digits, underscores and
# hyphens there.
module ::MinecraftServerDirectory
  PLUGIN_NAME = "minecraft-server-directory"
end

require_relative "lib/minecraft_server/version"
require_relative "lib/minecraft_server/address_policy"
require_relative "lib/minecraft_server/status_probe"
require_relative "lib/minecraft_server/engine"

enabled_site_setting :minecraft_server_enabled

register_asset "stylesheets/minecraft-servers.scss"
register_asset "stylesheets/minecraft-servers-admin.scss", :admin

add_admin_route(
  "minecraft_server.admin.title",
  ::MinecraftServerDirectory::PLUGIN_NAME,
  use_new_show_route: true,
)

after_initialize do
  # Plugin tables are not part of core's schema dumper. This keeps a development
  # database usable after `db:schema:load`, while production still runs migrations.
  if !Rails.env.production? && ActiveRecord::Base.connection.table_exists?(:minecraft_servers)
    MinecraftServerDirectory::Server.reset_column_information
  end
end