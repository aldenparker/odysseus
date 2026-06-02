# Odysseus on NixOS

Odysseus ships a Nix flake that exposes a package, a dev shell, and a
NixOS module. This document is a short pointer to each.

## Package

```sh
nix build github:aldenparker/odysseus
./result/bin/odysseus-server --help
./result/bin/odysseus               # CLI dispatcher
./result/bin/odysseus-setup         # init data/, DB, admin user
```

Provides three binaries on `$PATH`:

| Binary            | What it does                                           |
| ----------------- | ------------------------------------------------------ |
| `odysseus-server` | Runs uvicorn against `app:app`.                        |
| `odysseus-setup`  | First-run setup. Idempotent.                           |
| `odysseus`        | Subcommand dispatcher (`odysseus mail`, etc.).         |

## Dev shell

```sh
nix develop
python -m uvicorn app:app --host 127.0.0.1 --port 7000
pytest -q
```

Includes the full Python env plus `tmux`, `openssh`, `git`, `nodejs`,
`cmake`, `ruff`, and `mypy`. macOS development still uses the project's
existing `start-macos.sh`; the flake targets Linux only because
`chromadb`/`fastembed` aren't packaged for darwin in nixpkgs.

## NixOS module

Add the flake to your system inputs and import the module:

```nix
{
  inputs.odysseus.url = "github:aldenparker/odysseus";

  outputs = { self, nixpkgs, odysseus, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        odysseus.nixosModules.default
        ({ ... }: {
          services.odysseus = {
            enable = true;
            environment = {
              OLLAMA_BASE_URL = "http://127.0.0.1:11434/v1";
            };
            environmentFile = "/run/secrets/odysseus.env";  # OPENAI_API_KEY, HF_TOKEN, …
          };
        })
      ];
    };
  };
}
```

See `examples/minimal.nix` for the bare minimum and
`examples/full-stack.nix` for a deployment that also runs SearXNG and a
ChromaDB container alongside.

### State

The module routes every write into `services.odysseus.dataDir`
(default `/var/lib/odysseus`) via the `ODYSSEUS_DATA_DIR` and
`ODYSSEUS_LOG_DIR` env vars. Set those vars manually if running outside
the module.

### Secrets

Use `environmentFile` for anything sensitive — keep secrets out of the
Nix store. The plain `environment` attrset is for non-secret config
that's safe to materialise in `/nix/store`.

## Companion services

The module manages only odysseus. Run ChromaDB and SearXNG separately
(see `examples/full-stack.nix`). All three companion services that the
project's Docker compose bundles are URL-configured, so they can live
on any host.
