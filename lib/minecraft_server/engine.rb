# frozen_string_literal: true

module ::MinecraftServerDirectory
  class Engine < ::Rails::Engine
    engine_name "minecraft_server_directory"
    isolate_namespace MinecraftServerDirectory

    scheduled_job_dir = "#{config.root}/app/jobs/scheduled"
    config.to_prepare { Rails.autoloaders.main.eager_load_dir(scheduled_job_dir) }
  end
end