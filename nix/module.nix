{ config, lib, pkgs, ... }:

let
  cfg = config.services.odysseus;
in
{
  options.services.odysseus = {
    enable = lib.mkEnableOption "Odysseus AI workspace";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.odysseus or (pkgs.callPackage ./package.nix { });
      defaultText = lib.literalExpression "pkgs.odysseus";
      description = ''
        The odysseus package to use. Defaults to the package built by this
        flake; override to pin a specific revision or apply local patches.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "odysseus";
      description = "User account under which the odysseus service runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "odysseus";
      description = "Group under which the odysseus service runs.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/odysseus";
      description = ''
        Directory where Odysseus stores its SQLite database, uploads,
        caches, vector store, and logs. Created automatically.
      '';
    };

    listen = {
      address = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = ''
          Address to bind the HTTP server to. Use a loopback default and
          place a reverse proxy (nginx, caddy) in front for HTTPS.
        '';
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 7000;
        description = "Port the HTTP server listens on.";
      };
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        {
          LLM_HOST = "127.0.0.1";
          OLLAMA_BASE_URL = "http://127.0.0.1:11434/v1";
          CHROMADB_HOST = "127.0.0.1";
          CHROMADB_PORT = "8100";
          SEARXNG_INSTANCE = "http://127.0.0.1:8888";
        }
      '';
      description = ''
        Non-secret environment variables passed to the service. See
        .env.example in the source tree for the full list.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/odysseus.env";
      description = ''
        Path to a systemd EnvironmentFile holding secrets such as
        OPENAI_API_KEY or HF_TOKEN. Keep this outside the Nix store
        (e.g. sops-nix, agenix, or a plain root-owned file).
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to open the listen port in the firewall. Off by default
        because most deployments front odysseus with a reverse proxy.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      description = "Odysseus service user";
    };
    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}                   0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/data              0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/logs              0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/cache             0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/huggingface       0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/fastembed-cache   0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.odysseus = {
      description = "Odysseus AI workspace";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        # Route every write the app does into the mutable state dir; the
        # package itself stays read-only inside /nix/store.
        ODYSSEUS_DATA_DIR = "${cfg.dataDir}/data";
        ODYSSEUS_LOG_DIR = "${cfg.dataDir}/logs";
        HOME = cfg.dataDir;
        XDG_CACHE_HOME = "${cfg.dataDir}/cache";
        HF_HOME = "${cfg.dataDir}/huggingface";
        FASTEMBED_CACHE_PATH = "${cfg.dataDir}/fastembed-cache";
      } // cfg.environment;

      serviceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;

        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

        ExecStartPre = "${cfg.package}/bin/odysseus-setup";
        ExecStart = "${cfg.package}/bin/odysseus-server --host ${cfg.listen.address} --port ${toString cfg.listen.port}";

        Restart = "on-failure";
        RestartSec = "5s";

        # Sandboxing. The service only needs to write under dataDir;
        # everything else (the package, the system) is read-only.
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        ReadWritePaths = [ cfg.dataDir ];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.listen.port ];
  };

  meta.maintainers = [ ];
}
