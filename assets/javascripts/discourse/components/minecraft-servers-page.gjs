import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";
import { eq } from "discourse/truth-helpers";
import MinecraftServersIcon from "./minecraft-servers-icon";

const FILTERS = [
  { value: "all", label: "minecraft_server.filters.all" },
  { value: "online", label: "minecraft_server.filters.online" },
  { value: "offline", label: "minecraft_server.filters.offline" },
];

export default class MinecraftServersPage extends Component {
  @tracked filter = "all";
  @tracked copiedId = null;
  @tracked formValues = { name: "", address: "", description: "" };

  #copyTimer = null;

  get controller() {
    return this.args.controller;
  }

  get servers() {
    return this.controller?.servers ?? [];
  }

  get loading() {
    return this.controller?.loading ?? false;
  }

  get loadedOnce() {
    return this.controller?.loadedOnce ?? false;
  }

  get errorMessage() {
    return this.controller?.errorMessage;
  }

  get currentUser() {
    return this.controller?.currentUser;
  }

  get canSubmit() {
    return this.controller?.canSubmit ?? false;
  }

  get showForm() {
    return this.controller?.showForm ?? false;
  }

  get saving() {
    return this.controller?.saving ?? false;
  }

  get formError() {
    return this.controller?.formError;
  }

  get notice() {
    return this.controller?.notice;
  }

  get mine() {
    return this.controller?.mine ?? [];
  }

  get filters() {
    return FILTERS.map((filter) => {
      const count =
        filter.value === "all"
          ? this.servers.length
          : this.servers.filter((server) =>
              filter.value === "online" ? server.online : !server.online,
            ).length;

      return {
        ...filter,
        count,
        className: [
          "minecraft-servers__chip",
          this.filter === filter.value && "is-active",
        ]
          .filter(Boolean)
          .join(" "),
      };
    });
  }

  get visibleServers() {
    if (this.filter === "all") {
      return this.servers;
    }

    return this.servers.filter((server) =>
      this.filter === "online" ? server.online : !server.online,
    );
  }

  get showEmpty() {
    return this.loadedOnce && !this.errorMessage && this.visibleServers.length === 0;
  }

  get showSkeleton() {
    return !this.loadedOnce && !this.errorMessage;
  }

  get refreshLabel() {
    return this.loading
      ? "minecraft_server.actions.refreshing"
      : "minecraft_server.actions.refresh";
  }

  get editing() {
    return this.controller?.editing;
  }

  get formTitle() {
    return this.editing
      ? "minecraft_server.form.edit_title"
      : "minecraft_server.form.title";
  }

  get submitLabel() {
    return this.saving
      ? "minecraft_server.form.saving"
      : this.editing
        ? "minecraft_server.actions.save"
        : "minecraft_server.form.submit";
  }

  @action
  setFilter(value) {
    this.filter = value;
  }

  @action
  refresh() {
    return this.controller?.refresh();
  }

  @action
  openNewForm() {
    this.formValues = { name: "", address: "", description: "" };
    this.controller?.openNewForm();
  }

  @action
  openEditForm(server) {
    this.formValues = {
      name: server.name,
      address: server.address || "",
      description: server.description || "",
    };
    this.controller?.openEditForm(server);
  }

  @action
  updateField(field, event) {
    this.formValues = { ...this.formValues, [field]: event.target.value };
  }

  @action
  submitForm(event) {
    event.preventDefault();
    this.controller?.saveServer(this.formValues);
  }

  @action
  closeForm() {
    this.controller?.closeForm();
  }

  @action
  deleteServer(server) {
    return this.controller?.deleteServer(server);
  }

  @action
  probeServer(server) {
    return this.controller?.probeServer(server);
  }

  @action
  async copyAddress(server, event) {
    event?.preventDefault?.();
    event?.stopPropagation?.();

    const address = server?.address;
    if (!address) {
      return;
    }

    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(address);
      } else {
        const input = document.createElement("textarea");
        input.value = address;
        input.setAttribute("readonly", "");
        input.style.position = "fixed";
        input.style.opacity = "0";
        document.body.appendChild(input);
        input.select();
        document.execCommand("copy");
        input.remove();
      }

      this.copiedId = server.id;
      window.clearTimeout(this.#copyTimer);
      this.#copyTimer = window.setTimeout(() => (this.copiedId = null), 1600);
    } catch {
      this.copiedId = null;
    }
  }

  willDestroy() {
    window.clearTimeout(this.#copyTimer);
    super.willDestroy(...arguments);
  }

  statusKey(server) {
    if (server.status === "pending") {
      return "minecraft_server.status.pending";
    }
    if (server.status === "rejected") {
      return "minecraft_server.status.rejected";
    }
    if (server.status === "hidden") {
      return "minecraft_server.status.hidden";
    }
    if (!server.checked_at) {
      return "minecraft_server.status.unknown";
    }
    return server.online ? "minecraft_server.status.online" : "minecraft_server.status.offline";
  }

  statusClass(server) {
    if (server.status === "pending") {
      return "minecraft-servers__badge--pending";
    }
    return server.online
      ? "minecraft-servers__badge--online"
      : "minecraft-servers__badge--offline";
  }

  <template>
    <div class="minecraft-servers">
      <header class="minecraft-servers__hero">
        <div>
          <h1 class="minecraft-servers__title">{{i18n "minecraft_server.heading"}}</h1>
          <p class="minecraft-servers__subtitle">{{i18n "minecraft_server.description"}}</p>
        </div>

        <div class="minecraft-servers__actions">
          {{#if this.currentUser}}
            {{#if this.canSubmit}}
              <button
                type="button"
                class="btn btn-primary"
                {{on "click" this.openNewForm}}
              >
                <MinecraftServersIcon @name="plus" @size="14" />
                {{i18n "minecraft_server.actions.submit"}}
              </button>
            {{/if}}
          {{else}}
            <a class="btn btn-primary" href="/login">
              <MinecraftServersIcon @name="login" @size="14" />
              {{i18n "minecraft_server.actions.login"}}
            </a>
          {{/if}}
        </div>
      </header>

      {{#if this.notice}}
        <div class="minecraft-servers__notice">{{i18n this.notice}}</div>
      {{/if}}

      {{#if this.showForm}}
        <form class="minecraft-servers__form" {{on "submit" this.submitForm}}>
          <h2>{{i18n this.formTitle}}</h2>

          {{#if this.formError}}
            <div class="minecraft-servers__state minecraft-servers__error">{{this.formError}}</div>
          {{/if}}

          <div class="minecraft-servers__field">
            <label for="mc-server-name">{{i18n "minecraft_server.form.name"}}</label>
            <input
              id="mc-server-name"
              value={{this.formValues.name}}
              maxlength="80"
              required
              {{on "input" (fn this.updateField "name")}}
            />
          </div>

          <div class="minecraft-servers__field">
            <label for="mc-server-address">{{i18n "minecraft_server.form.address"}}</label>
            <input
              id="mc-server-address"
              value={{this.formValues.address}}
              maxlength="320"
              required
              {{on "input" (fn this.updateField "address")}}
            />
            <span class="minecraft-servers__hint">{{i18n "minecraft_server.form.address_hint"}}</span>
          </div>

          <div class="minecraft-servers__field">
            <label for="mc-server-description">{{i18n "minecraft_server.form.description"}}</label>
            <textarea
              id="mc-server-description"
              maxlength="1000"
              {{on "input" (fn this.updateField "description")}}
            >{{this.formValues.description}}</textarea>
            <span class="minecraft-servers__hint">{{i18n "minecraft_server.form.description_hint"}}</span>
          </div>

          <div class="minecraft-servers__actions">
            <button type="submit" class="btn btn-primary" disabled={{this.saving}}>
              {{i18n this.submitLabel}}
            </button>
            <button type="button" class="btn" {{on "click" this.closeForm}}>
              {{i18n "minecraft_server.actions.cancel"}}
            </button>
          </div>
        </form>
      {{/if}}

      <div class="minecraft-servers__bar">
        <div class="minecraft-servers__chips" role="group" aria-label={{i18n "minecraft_server.filters.all"}}>
          {{#each this.filters as |filter|}}
            <button
              type="button"
              class={{filter.className}}
              {{on "click" (fn this.setFilter filter.value)}}
            >
              {{i18n filter.label}}
              <span>{{filter.count}}</span>
            </button>
          {{/each}}
        </div>

        <button
          type="button"
          class="btn btn-small"
          disabled={{this.loading}}
          {{on "click" this.refresh}}
        >
          <MinecraftServersIcon @name="refresh" @size="14" />
          {{i18n this.refreshLabel}}
        </button>
      </div>

      {{#if this.errorMessage}}
        <div class="minecraft-servers__state minecraft-servers__error" role="alert">
          {{i18n this.errorMessage}}
        </div>
      {{/if}}

      {{#if this.showSkeleton}}
        <div class="minecraft-servers__state">{{i18n "minecraft_server.loading"}}</div>
      {{else if this.showEmpty}}
        <div class="minecraft-servers__state">
          <p>{{i18n "minecraft_server.empty"}}</p>
          <p>{{i18n "minecraft_server.empty_hint"}}</p>
        </div>
      {{/if}}

      {{#if this.visibleServers.length}}
        <div class="minecraft-servers__grid">
          {{#each this.visibleServers as |server|}}
            <article class="minecraft-servers__card">
              <div class="minecraft-servers__card-head">
                <h2 class="minecraft-servers__name">{{server.name}}</h2>
                <span class="minecraft-servers__badge {{this.statusClass server}}">
                  <span class="minecraft-servers__dot" aria-hidden="true"></span>
                  {{i18n (this.statusKey server)}}
                </span>
              </div>

              {{#if server.address}}
                <div class="minecraft-servers__address">{{server.address}}</div>
              {{/if}}

              {{#if server.description}}
                <p class="minecraft-servers__description">{{server.description}}</p>
              {{/if}}

              <div class="minecraft-servers__stats">
                <span>
                  <MinecraftServersIcon @name="user" @size="13" />
                  {{i18n "minecraft_server.players" online=server.players_online max=server.players_max}}
                </span>
                {{#if server.version_name}}
                  <span>{{server.version_name}}</span>
                {{/if}}
                {{#if server.latency_ms}}
                  <span>{{server.latency_ms}} ms</span>
                {{/if}}
              </div>

              {{#if server.motd}}
                <p class="minecraft-servers__motd">{{server.motd}}</p>
              {{/if}}

              <div class="minecraft-servers__card-actions">
                {{#if server.address}}
                  <button
                    type="button"
                    class="btn btn-small"
                    {{on "click" (fn this.copyAddress server)}}
                  >
                    {{#if (eq this.copiedId server.id)}}
                      <MinecraftServersIcon @name="check" @size="13" />
                      {{i18n "minecraft_server.actions.copied"}}
                    {{else}}
                      <MinecraftServersIcon @name="copy" @size="13" />
                      {{i18n "minecraft_server.actions.copy"}}
                    {{/if}}
                  </button>
                {{/if}}

                {{#if server.can_edit}}
                  <button type="button" class="btn btn-small" {{on "click" (fn this.openEditForm server)}}>
                    <MinecraftServersIcon @name="edit" @size="13" />
                    {{i18n "minecraft_server.actions.edit"}}
                  </button>
                  <button type="button" class="btn btn-small btn-danger" {{on "click" (fn this.deleteServer server)}}>
                    <MinecraftServersIcon @name="trash" @size="13" />
                    {{i18n "minecraft_server.actions.delete"}}
                  </button>
                {{/if}}
              </div>
            </article>
          {{/each}}
        </div>
      {{/if}}

      {{#if this.currentUser}}
        <section class="minecraft-servers__form">
          <h2>{{i18n "minecraft_server.mine.title"}}</h2>
          {{#if this.mine.length}}
            {{#each this.mine as |server|}}
              <div class="minecraft-servers__card">
                <div class="minecraft-servers__card-head">
                  <strong>{{server.name}}</strong>
                  <span class="minecraft-servers__badge {{this.statusClass server}}">
                    {{i18n (this.statusKey server)}}
                  </span>
                </div>
                <div class="minecraft-servers__address">{{server.address}}</div>
                <div class="minecraft-servers__card-actions">
                  <button type="button" class="btn btn-small" {{on "click" (fn this.probeServer server)}}>
                    {{i18n "minecraft_server.actions.probe"}}
                  </button>
                </div>
              </div>
            {{/each}}
          {{else}}
            <p class="minecraft-servers__hint">{{i18n "minecraft_server.mine.empty"}}</p>
          {{/if}}
        </section>
      {{/if}}
    </div>
  </template>
}