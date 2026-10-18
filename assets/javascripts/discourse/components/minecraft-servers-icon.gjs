import Component from "@glimmer/component";

const PATHS = {
  server:
    "M3 2.5h10a1 1 0 0 1 1 1v3a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1v-3a1 1 0 0 1 1-1Zm0 6h10a1 1 0 0 1 1 1v3a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1v-3a1 1 0 0 1 1-1ZM4.75 5h.01M4.75 11h.01",
  user: "M8 7.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM3 13.5c0-2.21 2.24-4 5-4s5 1.79 5 4",
  refresh: "M13.5 8a5.5 5.5 0 1 1-1.61-3.89M13.5 2.5v3.2h-3.2",
  copy: "M5.5 5.5h6a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1h-6a1 1 0 0 1-1-1v-6a1 1 0 0 1 1-1Zm-1-1v-1.5a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v1.5",
  check: "M3 8.5 6.2 11.7 13 4.5",
  alert: "M8 2.5 14 13H2L8 2.5Zm0 4v3.2m0 1.8v.5",
  plus: "M8 3v10M3 8h10",
  edit: "M3 11.5 11.5 3l1.5 1.5L4.5 13H3v-1.5Z",
  trash: "M4 5h8M6 5V3.5h4V5m-5 0 .6 8h4.8L11 5",
  login: "M6.5 3.5h-3a1 1 0 0 0-1 1v7a1 1 0 0 0 1 1h3M10 5.5 12.5 8 10 10.5M12.5 8h-6",
};

export default class MinecraftServersIcon extends Component {
  get path() {
    return PATHS[this.args.name] ?? PATHS.alert;
  }

  get size() {
    return this.args.size ?? 16;
  }

  <template>
    <svg
      class="minecraft-servers__icon"
      width={{this.size}}
      height={{this.size}}
      viewBox="0 0 16 16"
      fill="none"
      stroke="currentColor"
      stroke-width="1.4"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      <path d={{this.path}} />
    </svg>
  </template>
}