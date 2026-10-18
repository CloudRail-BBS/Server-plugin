import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class MinecraftServersStatusRoute extends DiscourseRoute {
  model() {
    return ajax("/minecraft-servers/admin/servers.json").catch(() => ({
      servers: [],
      counts: {},
    }));
  }
}