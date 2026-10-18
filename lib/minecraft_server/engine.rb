# frozen_string_literal: true

module ::MinecraftServer
  class Engine < ::Rails::Engine
    engine_name "minecraft_server_directory"
    isolate_namespace MinecraftServer

    scheduled_job_dir = "#{config.root}/app/jobs/scheduled"
    config.to_prepare { Rails.autoloaders.main.eager_load_dir(scheduled_job_dir) }
  end
end