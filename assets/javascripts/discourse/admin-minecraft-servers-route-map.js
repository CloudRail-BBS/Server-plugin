export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("minecraft-servers-status", { path: "minecraft-servers" });
  },
};