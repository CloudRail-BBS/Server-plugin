# frozen_string_literal: true

module ::MinecraftServerDirectory
  class ServersController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_enabled
    before_action :ensure_logged_in, only: %i[mine create update destroy refresh]

    def index
      render json: {
        servers: serialize(ServerRegistry.list.limit(200)),
        meta: {
          total: ServerRegistry.list.count,
          show_ip: SiteSetting.minecraft_server_show_ip,
          refresh_seconds: SiteSetting.minecraft_server_refresh_seconds,
          plugin_version: VERSION,
        },
      }
    end

    def mine
      render json: { servers: serialize(ServerRegistry.mine(current_user)) }
    end

    def create
      server = ServerRegistry.submit(user: current_user, params: server_params)
      render json: { server: serialize_one(server) }, status: :created
    rescue AddressPolicy::Error => e
      render_json_error(e.message, status: 422)
    end

    def update
      server = find_server
      ServerRegistry.update(user: current_user, server: server, params: server_params)
      render json: { server: serialize_one(server) }
    rescue AddressPolicy::Error => e
      render_json_error(e.message, status: 422)
    end

    def destroy
      server = find_server
      raise Discourse::InvalidAccess unless server.can_edit?(current_user)
      server.destroy!
      render json: { success: true }
    end

    def refresh
      server = find_server
      ServerRegistry.refresh!(server, current_user)
      render json: { server: serialize_one(server.reload) }
    rescue AddressPolicy::Error => e
      render_json_error(e.message, status: 422)
    end

    private

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.minecraft_server_enabled
    end

    def ensure_logged_in
      raise Discourse::InvalidAccess if current_user.blank?
    end

    def find_server
      Server.find(params[:id])
    end

    def server_params
      params.require(:server).permit(:name, :address, :description).to_h.symbolize_keys
    end

    def serialize(records)
      records.map { |record| serialize_one(record) }
    end

    def serialize_one(record)
      ServerSerializer.new(record, scope: guardian, root: false).as_json
    end
  end
end