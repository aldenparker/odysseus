{
  description = "Odysseus — self-hosted AI workspace (chat, agents, RAG, email, calendar)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      # Linux only for now — chromadb / fastembed are not packaged for
      # darwin in nixpkgs at the time of writing. The dev workflow on
      # macOS still works through the project's start-macos.sh script.
      perSystem = flake-utils.lib.eachSystem [
        "x86_64-linux"
        "aarch64-linux"
      ] (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          odysseus = pkgs.callPackage ./nix/package.nix {
            appSrc = self;
          };
        in
        {
          packages = {
            default = odysseus;
            odysseus = odysseus;
          };

          devShells.default = pkgs.mkShell {
            packages = [
              odysseus.passthru.pythonEnv
              # Runtime tools the app shells out to.
              pkgs.tmux
              pkgs.openssh
              pkgs.git
              pkgs.nodejs
              pkgs.cmake
              # Lint and format.
              pkgs.ruff
              pkgs.mypy
              # Nix tooling.
              pkgs.nixfmt
              pkgs.nix-tree
            ];

            shellHook = ''
              echo "odysseus dev shell"
              echo "  python: $(${odysseus.passthru.pythonEnv}/bin/python --version)"
              echo "  start:  python -m uvicorn app:app --host 127.0.0.1 --port 7000"
              echo "  setup:  python setup.py"
              echo "  tests:  pytest -q"
            '';
          };

          checks = {
            package = odysseus;
            # Light import smoke test — the python env can load every
            # dependency declared in requirements.txt.
            python-imports = pkgs.runCommand "odysseus-python-imports" { } ''
              ${odysseus.passthru.pythonEnv}/bin/python - <<'PY'
              import fastapi, uvicorn, pydantic, sqlalchemy, httpx, bcrypt
              import chromadb, fastembed, mcp, caldav, croniter, pyotp
              import bs4, markdown, icalendar, dateutil.rrule
              import pypdf, qrcode, youtube_transcript_api
              print("ok")
              PY
              touch $out
            '';
            # End-to-end NixOS integration test: boots a VM with the module
            # enabled, waits for the systemd unit, and asserts the health
            # and version endpoints respond. Confirms that the wrapper,
            # tmpfiles, env wiring, and sandboxing all hang together.
            vm = pkgs.testers.nixosTest {
              name = "odysseus";
              nodes.machine = {
                imports = [ ./nix/module.nix ];
                nixpkgs.overlays = [ self.overlays.default ];
                services.odysseus = {
                  enable = true;
                  listen.port = 7000;
                };
                # The VM's tiny default of 1024MB leaves no headroom once
                # fastembed/chromadb load their ONNX runtimes.
                virtualisation.memorySize = 2048;
              };
              testScript = ''
                machine.wait_for_unit("odysseus.service")
                machine.wait_for_open_port(7000)
                machine.succeed("curl -fsS http://127.0.0.1:7000/api/health | grep healthy")
                machine.succeed("curl -fsS http://127.0.0.1:7000/api/version | grep version")
                # State landed in /var/lib/odysseus and is owned by the
                # service user, not root.
                machine.succeed("test -f /var/lib/odysseus/data/app.db")
                machine.succeed("stat -c '%U' /var/lib/odysseus/data/app.db | grep -x odysseus")
              '';
            };
          };

          formatter = pkgs.nixfmt;
        }
      );
    in
    perSystem
    // {
      overlays.default = import ./nix/overlay.nix;

      nixosModules = rec {
        odysseus = ./nix/module.nix;
        default = odysseus;
      };
    };
}
