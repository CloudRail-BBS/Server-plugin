import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

const SERVERS_URL = "/minecraft-servers/servers.json";
const MINE_URL = "/minecraft-servers/mine.json";
const MIN_REFRESH_SECONDS = 10;

export default class MinecraftServersIndexController extends Controller {
  @service siteSettings;
  @service currentUser;

  @tracked servers = [];
  @tracked meta = null;
  @tracked loading = false;
  @tracked loadedOnce = false;
  @tracked errorMessage = null;
  @tracked mine = [];
  @tracked showForm = false;
  @tracked editing = null;
  @tracked saving = false;
  @tracked notice = null;
  @tracked formError = null;

  #timer = null;
  #visibilityHandler = null;
  #destroyed = false;

  get refreshSeconds() {
    const value = Number(this.siteSettings.minecraft_server_refresh_seconds) || 30;
    return Math.max(value, MIN_REFRESH_SECONDS);
  }

  get canSubmit() {
    return Boolean(
      this.currentUser &&
        this.siteSettings.minecraft_server_allow_user_submissions &&
        (this.currentUser.staff ||
          this.currentUser.trust_level >=
            Number(this.siteSettings.minecraft_server_min_trust_level || 0)),
    );
  }

  init() {
    super.init(...arguments);
    this.#visibilityHandler = () => {
      if (document.hidden) {
        this.#clearTimer();
      } else {
        this.refresh();
      }
    };
  }

  applyPayload(payload) {
    if (!payload || typeof payload !== "object") {
      this.errorMessage = "minecraft_server.offline";
      return;
    }

    this.servers = Array.isArray(payload.servers) ? payload.servers : [];
    this.meta = payload.meta ?? null;
    this.errorMessage = null;
    this.loadedOnce = true;
  }

  startPolling() {
    this.#scheduleNext();
    document.addEventListener("visibilitychange", this.#visibilityHandler);
    if (this.currentUser) {
      this.loadMine();
    }
  }

  stopPolling() {
    this.#clearTimer();
    document.removeEventListener("visibilitychange", this.#visibilityHandler);
  }

  willDestroy() {
    this.#destroyed = true;
    this.stopPolling();
    super.willDestroy(...arguments);
  }

  async loadMine() {
    try {
      const payload = await ajax(MINE_URL);
      this.mine = Array.isArray(payload?.servers) ? payload.servers : [];
    } catch {
      this.mine = [];
    }
  }

  @action
  async refresh() {
    if (this.loading) {
      return;
    }

    this.loading = true;
    try {
      this.applyPayload(await ajax(SERVERS_URL));
      if (this.currentUser) {
        await this.loadMine();
      }
    } catch {
      this.errorMessage = "minecraft_server.offline";
    } finally {
      this.loading = false;
      this.loadedOnce = true;
      this.#scheduleNext();
    }
  }

  @action
  openNewForm() {
    this.editing = null;
    this.formError = null;
    this.notice = null;
    this.showForm = true;
  }

  @action
  openEditForm(server) {
    this.editing = server;
    this.formError = null;
    this.notice = null;
    this.showForm = true;
  }

  @action
  closeForm() {
    this.showForm = false;
    this.editing = null;
    this.formError = null;
  }

  @action
  async saveServer(formValues) {
    if (this.saving) {
      return;
    }

    this.saving = true;
    this.formError = null;
    this.notice = null;

    const editingId = this.editing?.id;
    const url = editingId
      ? `/minecraft-servers/servers/${editingId}`
      : "/minecraft-servers/servers";
    const method = editingId ? "PUT" : "POST";

    try {
      const payload = await ajax(url, {
        type: method,
        dataType: "json",
        contentType: "application/json",
        data: JSON.stringify({ server: formValues }),
      });

      const server = payload?.server;
      this.notice =
        server?.status === "pending"
          ? "minecraft_server.form.success_pending"
          : editingId
            ? "minecraft_server.form.success_updated"
            : "minecraft_server.form.success";

      this.showForm = false;
      this.editing = null;
      await this.refresh();
      await this.loadMine();
    } catch (error) {
      this.formError =
        error?.jqXHR?.responseJSON?.errors?.[0] || "minecraft_server.errors.generic";
    } finally {
      this.saving = false;
    }
  }

  @action
  async deleteServer(server) {
    if (!server?.can_edit) {
      return;
    }

    try {
      await ajax(`/minecraft-servers/servers/${server.id}`, { type: "DELETE" });
      await this.refresh();
      await this.loadMine();
    } catch {
      this.errorMessage = "minecraft_server.errors.generic";
    }
  }

  @action
  async probeServer(server) {
    try {
      await ajax(`/minecraft-servers/servers/${server.id}/refresh`, {
        type: "POST",
      });
      await this.refresh();
    } catch {
      this.errorMessage = "minecraft_server.errors.generic";
    }
  }

  #scheduleNext() {
    this.#clearTimer();
    if (document.hidden || this.#destroyed) {
      return;
    }

    this.#timer = window.setTimeout(() => this.refresh(), this.refreshSeconds * 1000);
  }

  #clearTimer() {
    if (this.#timer) {
      window.clearTimeout(this.#timer);
      this.#timer = null;
    }
  }
}