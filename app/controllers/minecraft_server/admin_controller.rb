# frozen_string_literal: true

module ::MinecraftServerDirectory
  class AdminController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_admin

    def index
      status = params[:status].to_s
      scope = Server.includes(:user).order(created_at: :desc)
      scope = scope.where(status: status) if Server::STATUSES.include?(status)

      render json: {
        servers: scope.limit(500).map { |server| serialize_one(server) },
        counts: Server.group(:status).count,
      }
    end

    def update
      server = Server.find(params[:id])
      action = params.dig(:server, :status).to_s
      case action
      when "approved"
        ServerRegistry.approve!(server, current_user)
      when "rejected"
        ServerRegistry.reject!(server, current_user)
      when "hidden"
        ServerRegistry.hide!(server, current_user)
      else
        raise Discourse::InvalidParameters.new(:status)
      end

      render json: { server: serialize_one(server.reload) }
    end

    def destroy
      Server.find(params[:id]).destroy!
      render json: { success: true }
    end

    def refresh
      server = Server.find(params[:id])
      ServerRegistry.probe_one(server)
      render json: { server: serialize_one(server.reload) }
    end

    private

    def ensure_admin
      raise Discourse::NotFound unless SiteSetting.minecraft_server_enabled
      raise Discourse::InvalidAccess unless current_user&.admin?
    end

    def serialize_one(server)
      ServerSerializer.new(server, scope: guardian, root: false).as_json
    end
  end
end