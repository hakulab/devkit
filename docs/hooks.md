# Hooks

## Set up the dev shell

Add `preCommit` to `inputsFrom` as shown in [Nix flake](flake.md). The shell's own `packages` and `nativeBuildInputs` take precedence over hook packages on `PATH`.

Enter the dev shell from the checkout where you intend to install the hooks. Its configuration path must either be absent or point into the Nix store through a symlink. Installing prek's shims replaces existing hooks, including the targets of symlinked hooks.

Hook installation is silent on success and reports errors on stderr, so `direnv` stays quiet and callers of `nix develop -c <cmd>` can read the command's output from stdout. Keep stdout clear in the repository's own `shellHook` for the same reason.

As in CI, run `run-hooks` separately from `nix flake check`. The hook runner prepares dependencies for enabled lockfile-pinned tools, then checks tracked files across the pre-commit, pre-merge-commit, and pre-push stages. To run a subset, pass hook IDs as in `nix develop -c run-hooks cspell`.

```bash
nix develop -c run-hooks
```

## Enable hooks

The baseline enables file hygiene, spelling, EditorConfig, Markdown formatting and linting, Nix checks, YAML syntax, and GitHub Actions linting. Use `hooks.<name>.enable` to turn off a default or opt into a project-specific check.

| Project files             | Hooks to enable               | Scope                                                                       |
| ------------------------- | ----------------------------- | --------------------------------------------------------------------------- |
| Documentation             | `doctoc`, `lychee`            | Maintain marked tables of contents or check links                           |
| JavaScript and TypeScript | `eslint`, `tsc`               | Lint selected scripts or type-check the project                             |
| Web formats and TOML      | `prettier`, `taplo`           | Format JS, TS, CSS, JSON, JSONC, and YAML with Prettier, or TOML with Taplo |
| Nushell                   | `nu-check`                    | Check scripts with the project's module search paths                        |
| Python                    | `mypy`, `ruff`, `ruff-format` | Type-check, lint, or format                                                 |
| Rust                      | `clippy`, `rustfmt`           | Lint or format with the project's toolchain                                 |
| Shell                     | `shellcheck`, `shfmt`         | Lint or format shell scripts                                                |

ESLint and clippy treat warnings as errors because prek hides the output of a passing hook. See the [baseline](../nix/hooks/baseline.nix) for individual defaults and the [upstream hook definitions](https://github.com/cachix/git-hooks.nix/blob/master/modules/hooks.nix) for settings.

## Configure a hook

### Override the baseline

A definition under `hooks` generally replaces the baseline value. The `args` and `excludes` lists append by default, so wrap them in `lib.mkForce` when you need to replace them.

```nix
preCommit = dk.preCommit {
  src = ./.;
  hooks = {
    prettier = {
      enable = true;
      files = "\\.(json|ya?ml)$";
    };
    trim-trailing-whitespace.excludes = [
      "\\.patch$"
    ];
    cspell.args = lib.mkForce [
      "--no-progress"
    ];
  };
};
```

### Use a project configuration file

- A standalone **Prettier** config at the project root replaces the [shared config](../.prettierrc.json). The hook checks `.prettierrc.json` first, then follows [Prettier's order](https://prettier.io/docs/configuration) for standalone files. It disables EditorConfig. Use native discovery for manifest settings or nested configs. In the shared config, use basename globs for overrides because Prettier resolves them from the Nix store.
- A root **Taplo** config (`.taplo.toml`) replaces the shared config. Copy the [shared file](../.taplo.toml) to the project root for native discovery.
- A project **markdownlint-cli2** config (`.markdownlint-cli2.jsonc`) overrides rules from the [shared CLI2 config](../.markdownlint-cli2.jsonc). Relative `customRules` and `markdownItPlugins` require `configPath = ".markdownlint-cli2.jsonc"`. For an explicit project config or native discovery, use `config.extends` with a workspace-relative copy of the [shared rules](../.markdownlint.jsonc).

Re-enter the dev shell after adding a root Prettier or Taplo config. For these hooks and Ruff, set `hooks.<name>.settings.configPath = ""` to use native discovery, or set it to a specific file.

### Add a spelling dictionary

Name the project dictionary in `cspell.json`. The `sort-file-contents` hook sorts `.cspell/words.txt` by default, so set `hooks.sort-file-contents.files` if you keep the dictionary elsewhere.

### Generate Markdown tables of contents

doctoc fills a table of contents between `<!-- START doctoc -->` and `<!-- END doctoc -->` markers placed where the list goes, leaving a file without them untouched. In marked files, use inline links in headings so doctoc generates anchors matching GitHub.

### Format Markdown

The dprint hook formats tracked Markdown even when it matches Git ignore rules. Native dprint can use or extend [`dprint.json`](../dprint.json), which downloads the same pinned WASM that the Nix hook loads from the store. Additional language plugins can reformat fenced examples. Pass editor buffers with `--stdin md`, since an absolute buffer path can be skipped by file selection.

### Check EditorConfig properties

Copy the shared [`.editorconfig`](../.editorconfig) for native discovery. Keep its Markdown exception for two-space hard line breaks. Use `hooks.editorconfig-checker.excludes` for binary payloads the checker treats as text.

### Check Nushell files

Set `hooks.nu-check.settings.libDirs` to any module directories that scripts `use` by name, as [Share modules](nushell.md#share-modules) describes.

### Type-check Python

mypy checks the `files` that `[tool.mypy]` names, whichever files changed.

### Lint and format Python

To run both Ruff hooks at the version in `uv.lock`, add `ruff` to the `dev` dependency group and set the package once.

```nix
hooks.ruff.package = dk.uvTool "ruff";
```

### Lint and format Rust

Point clippy and rustfmt at the repository's toolchain so the hooks use the same compiler and formatter as local development.

```nix
hooks = {
  clippy.packageOverrides = {
    cargo = rustToolchain;
    clippy = rustToolchain;
  };
  rustfmt.packageOverrides = {
    cargo = rustToolchain;
    rustfmt = rustToolchain;
  };
};
```

Set Cargo flags in `hooks.clippy.settings` and lint levels in `Cargo.toml` `[lints]`. clippy runs with `--locked --all-targets`, so commit `Cargo.lock` or replace `settings.extraArgs`.

### Check shell files

Start the repository's `.envrc` with a shell directive so shellcheck can lint it without a shebang.

```bash
# shellcheck shell=bash
```

## Run a lockfile-pinned tool

ESLint and TypeScript use `pnpm-lock.yaml`, and mypy uses `uv.lock`. For hooks that need project dependencies, set the package via `dk.nodeTool` or `dk.uvTool`. Include the matching toolchain in the dev shell to use the same runtime versions interactively.

### Declare pnpm

Declare pnpm in `package.json` with a `devEngines` range that matches the toolchain's major version.

```json
{
  "devEngines": {
    "packageManager": {
      "name": "pnpm",
      "version": "^12.0.0",
      "onFail": "error"
    }
  }
}
```

Omit the top-level `packageManager` field because it makes pnpm download and run that exact version. When `devEngines` names pnpm, npm refuses to run inside the project. Use `pnpm publish` for OIDC trusted publishing and run npm-only commands from outside the checkout.

### Declare uv

Set uv's version floor and interpreter in `pyproject.toml` so they apply to each `uv` invocation, both inside and outside the dev shell.

```toml
[tool.uv]
required-version = ">=0.13"
python-downloads = "never"
python-preference = "only-system"
```

Use `required-version` to stop older versions of uv before they rewrite `uv.lock` to an older revision. The `system` preference allows a `.venv` built with a uv-managed Python to stay in place. Set `only-system` to replace that environment with the dev shell's Python, and include the `pkgs.python3xx` that satisfies `requires-python` in the shell.

## Exclude files

The baseline excludes paths containing a `__fixtures__/`, `fixtures/`, `__snapshots__/`, or `testdata/` component to preserve byte-exact test data (conventional fixture and snapshot directories across ecosystems). Add repository-specific exclusions through `excludes` in `dk.preCommit`.
