# frozen_string_literal: true

module ::Jobs
  class MinecraftServerProbe < ::Jobs::Scheduled
    every 5.minutes

    def execute(args)
      return 0 unless SiteSetting.minecraft_server_enabled

      interval = SiteSetting.minecraft_server_probe_interval_minutes.to_i.minutes
      servers = MinecraftServer::Server.due_for_probe(Time.zone.now - interval).limit(50).to_a

      servers.count do |server|
        begin
          MinecraftServer::ServerRegistry.probe_one(server)
          true
        rescue StandardError => e
          Rails.logger.warn("minecraft-server probe failed for #{server.id}: #{e.message}")
          false
        end
      end
    end
  end
end