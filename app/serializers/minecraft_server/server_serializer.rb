# frozen_string_literal: true

module ::MinecraftServerDirectory
  class ServerSerializer < ::ApplicationSerializer
    attributes :id,
               :name,
               :address,
               :host,
               :port,
               :description,
               :status,
               :listed,
               :online,
               :players_online,
               :players_max,
               :version_name,
               :motd,
               :favicon,
               :latency_ms,
               :checked_at,
               :last_error,
               :can_edit,
               :can_manage,
               :owner_username,
               :created_at

    def address
      SiteSetting.minecraft_server_show_ip || scope&.user&.staff? || can_edit ? object.display_address : nil
    end

    def favicon
      object.favicon.presence
    end

    def can_edit
      object.can_edit?(scope&.user)
    end

    def can_manage
      !!scope&.is_staff?
    end

    def owner_username
      object.user&.username
    end

    def checked_at
      object.checked_at&.iso8601
    end
  end
end