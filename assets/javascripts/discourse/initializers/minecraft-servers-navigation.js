import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

const ROUTE = "minecraft-servers";
const LINK_NAME = "minecraft-servers-nav-link";

export default {
  name: "minecraft-servers-navigation",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.minecraft_server_enabled) {
      return;
    }

    withPluginApi((api) => {
      const title = () => i18n("minecraft_server.nav_label");

      api.addCommunitySectionLink({
        name: LINK_NAME,
        route: ROUTE,
        title: title(),
        text: title(),
        icon: "server",
      });

      api.addNavigationBarItem({
        name: LINK_NAME,
        displayName: title(),
        href: "/minecraft-servers",
      });
    });
  },
};