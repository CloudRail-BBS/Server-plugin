import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { eq } from "discourse/truth-helpers";

const FILTERS = [
  { value: "", label: "minecraft_server.admin.all" },
  { value: "pending", label: "minecraft_server.admin.pending" },
  { value: "approved", label: "minecraft_server.admin.approved" },
  { value: "rejected", label: "minecraft_server.admin.rejected" },
  { value: "hidden", label: "minecraft_server.admin.hidden" },
];

export default class MinecraftServersAdmin extends Component {
  @service siteSettings;
  @tracked filter = "";
  @tracked payload = null;
  @tracked workingId = null;
  @tracked errorMessage = null;

  get data() {
    return this.payload ?? this.args.model ?? { servers: [], counts: {} };
  }

  get servers() {
    return Array.isArray(this.data.servers) ? this.data.servers : [];
  }

  get counts() {
    return this.data.counts ?? {};
  }

  get filters() {
    return FILTERS.map((filter) => ({
      ...filter,
      count: filter.value ? this.counts[filter.value] ?? 0 : this.servers.length,
      className: [
        "btn btn-small",
        this.filter === filter.value && "btn-primary",
      ]
        .filter(Boolean)
        .join(" "),
    }));
  }

  get enabled() {
    return Boolean(this.siteSettings.minecraft_server_enabled);
  }

  @action
  async setFilter(value) {
    this.filter = value;
    await this.load();
  }

  @action
  async load() {
    this.errorMessage = null;
    try {
      const url = this.filter
        ? `/minecraft-servers/admin/servers.json?status=${this.filter}`
        : "/minecraft-servers/admin/servers.json";
      this.payload = await ajax(url);
    } catch {
      this.errorMessage = "minecraft_server.errors.generic";
    }
  }

  @action
  async setStatus(server, status) {
    if (this.workingId) {
      return;
    }

    this.workingId = server.id;
    this.errorMessage = null;
    try {
      await ajax(`/minecraft-servers/admin/servers/${server.id}`, {
        type: "PUT",
        dataType: "json",
        contentType: "application/json",
        data: JSON.stringify({ server: { status } }),
      });
      await this.load();
    } catch {
      this.errorMessage = "minecraft_server.errors.generic";
    } finally {
      this.workingId = null;
    }
  }

  @action
  async probe(server) {
    this.workingId = server.id;
    try {
      await ajax(`/minecraft-servers/admin/servers/${server.id}/refresh`, {
        type: "POST",
      });
      await this.load();
    } catch {
      this.errorMessage = "minecraft_server.errors.generic";
    } finally {
      this.workingId = null;
    }
  }

  @action
  async remove(server) {
    this.workingId = server.id;
    try {
      await ajax(`/minecraft-servers/admin/servers/${server.id}`, {
        type: "DELETE",
      });
      await this.load();
    } catch {
      this.errorMessage = "minecraft_server.errors.generic";
    } finally {
      this.workingId = null;
    }
  }

  statusLabel(status) {
    return `minecraft_server.status.${status}`;
  }

  <template>
    <div class="minecraft-servers-admin">
      <h2>{{i18n "minecraft_server.admin.title"}}</h2>
      <p>{{i18n "minecraft_server.admin.description"}}</p>

      {{#unless this.enabled}}
        <div class="alert alert-info">{{i18n "minecraft_server.errors.disabled"}}</div>
      {{/unless}}

      {{#if this.errorMessage}}
        <div class="alert alert-error">{{i18n this.errorMessage}}</div>
      {{/if}}

      <div class="minecraft-servers-admin__toolbar">
        {{#each this.filters as |filter|}}
          <button
            type="button"
            class={{filter.className}}
            {{on "click" (fn this.setFilter filter.value)}}
          >
            {{i18n filter.label}} ({{filter.count}})
          </button>
        {{/each}}
      </div>

      {{#if this.servers.length}}
        <table class="minecraft-servers-admin__table">
          <thead>
            <tr>
              <th>{{i18n "minecraft_server.form.name"}}</th>
              <th>{{i18n "minecraft_server.form.address"}}</th>
              <th>{{i18n "minecraft_server.admin.owner"}}</th>
              <th>{{i18n "minecraft_server.table.status"}}</th>
              <th>{{i18n "minecraft_server.actions.probe"}}</th>
            </tr>
          </thead>
          <tbody>
            {{#each this.servers as |server|}}
              <tr>
                <td>
                  <strong>{{server.name}}</strong>
                  {{#if server.description}}
                    <div class="minecraft-servers__hint">{{server.description}}</div>
                  {{/if}}
                </td>
                <td class="minecraft-servers-admin__mono">
                  {{server.address}}
                  {{#if server.last_error}}
                    <div class="minecraft-servers__hint">{{server.last_error}}</div>
                  {{/if}}
                </td>
                <td>{{server.owner_username}}</td>
                <td>
                  {{i18n (this.statusLabel server.status)}}
                  <div class="minecraft-servers__hint">
                    {{i18n "minecraft_server.players" online=server.players_online max=server.players_max}}
                  </div>
                </td>
                <td>
                  <div class="minecraft-servers-admin__actions">
                    <button type="button" class="btn btn-small" {{on "click" (fn this.probe server)}}>
                      {{i18n "minecraft_server.actions.probe"}}
                    </button>
                    {{#if (eq server.status "approved")}}
                      <button type="button" class="btn btn-small" {{on "click" (fn this.setStatus server "hidden")}}>
                        {{i18n "minecraft_server.actions.hide"}}
                      </button>
                    {{else}}
                      <button type="button" class="btn btn-small btn-primary" {{on "click" (fn this.setStatus server "approved")}}>
                        {{i18n "minecraft_server.actions.approve"}}
                      </button>
                    {{/if}}
                    <button type="button" class="btn btn-small" {{on "click" (fn this.setStatus server "rejected")}}>
                      {{i18n "minecraft_server.actions.reject"}}
                    </button>
                    <button type="button" class="btn btn-small btn-danger" {{on "click" (fn this.remove server)}}>
                      {{i18n "minecraft_server.actions.delete"}}
                    </button>
                  </div>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <div class="minecraft-servers-admin__empty">{{i18n "minecraft_server.admin.no_servers"}}</div>
      {{/if}}
    </div>
  </template>
}