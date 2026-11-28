# ==================================================================================================
# Dprint Configuration
# ==================================================================================================

{
  pkgs,
  repo,
}:

let
  inherit (pkgs) lib;
  config = lib.importJSON (lib.path.append repo.root "dprint.json");
  dprint-plugin-markdown = pkgs.callPackage ./packages/dprint-plugin-markdown.nix {
    url = lib.head config.plugins;
  };
in
assert lib.length config.plugins == 1;
pkgs.writers.writeJSON "dprint.json" (
  config
  // {
    plugins = [ "${dprint-plugin-markdown}/plugin.wasm" ];
  }
)
