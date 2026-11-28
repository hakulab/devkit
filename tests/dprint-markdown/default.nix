# ==================================================================================================
# Dprint Markdown Check
# ==================================================================================================

{
  pkgs,
  dk,
}:

pkgs.runCommand "dprint-markdown"
  {
    nativeBuildInputs = [ dk.dprint ];
  }
  ''
    cp ${./fixtures/input.md} formatted.md
    chmod +w formatted.md
    export DPRINT_CACHE_DIR="$TMPDIR/dprint-cache"
    dprint fmt --config=${dk.dprintConfig} formatted.md
    diff -u ${./fixtures/expected.md} formatted.md
    touch "$out"
  ''
