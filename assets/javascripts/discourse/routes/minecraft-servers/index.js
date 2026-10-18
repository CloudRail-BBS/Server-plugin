import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { action } from "@ember/object";

const SERVERS_URL = "/minecraft-servers/servers.json";
const MINE_URL = "/minecraft-servers/mine.json";

export default class MinecraftServersIndexRoute extends DiscourseRoute {
  model() {
    return ajax(SERVERS_URL).catch(() => ({ servers: [], meta: null }));
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.applyPayload(model);
    controller.startPolling();
  }

  @action
  willTransition() {
    this.controllerFor("minecraft-servers.index")?.stopPolling();
    return true;
  }
}

export { SERVERS_URL, MINE_URL };