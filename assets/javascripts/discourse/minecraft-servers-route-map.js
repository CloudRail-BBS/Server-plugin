// Top-level route map. The function form attaches to the main application route
// tree; the object form only attaches to an already existing route node.
export default function () {
  this.route("minecraft-servers", { path: "/minecraft-servers" }, function () {
    this.route("index", { path: "/" });
  });
}