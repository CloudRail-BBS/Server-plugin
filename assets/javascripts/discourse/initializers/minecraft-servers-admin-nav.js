import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "minecraft-server-directory";

export default {
  name: "minecraft-servers-admin-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "server");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "minecraft_server.admin.title",
          route: "adminPlugins.show.minecraft-servers-status",
        },
      ]);
    });
  },
};