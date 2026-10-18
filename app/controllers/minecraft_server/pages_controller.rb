# frozen_string_literal: true

module ::MinecraftServer
  class PagesController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr, only: :index

    def index
      raise Discourse::NotFound unless SiteSetting.minecraft_server_enabled
      @servers = ServerRegistry.list.limit(100)
      @page_title = I18n.t("minecraft_server.page.title")
      render :index
    end
  end
end