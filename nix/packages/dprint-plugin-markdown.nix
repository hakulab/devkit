# ==================================================================================================
# Dprint Markdown Plugin
# ==================================================================================================

{
  pkgs,
  url,
}:

pkgs.dprint-plugins.dprint-plugin-markdown.overrideAttrs (_: {
  # Current nixpkgs pins 0.20.0, which rewrites protected content.
  version = "0.29.0";

  src = pkgs.fetchurl {
    inherit url;
    hash = "sha256-cUrqdVXdmDGGG+Rm2osmstkjFtPN5VDvPh9jsx9OowI=";
  };
})
