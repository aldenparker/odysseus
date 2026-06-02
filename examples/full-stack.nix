# Full-stack NixOS deployment: odysseus + SearXNG (web search) + ChromaDB
# (vector store for semantic memory and RAG).
#
# SearXNG ships in nixpkgs as services.searx. ChromaDB has no nixpkgs
# module, so we run the upstream container via virtualisation.oci-containers.
{ pkgs, ... }:
{
  imports = [
    ../nix/module.nix
  ];

  services.odysseus = {
    enable = true;

    listen = {
      address = "127.0.0.1";
      port = 7000;
    };

    environment = {
      LLM_HOST = "127.0.0.1";
      OLLAMA_BASE_URL = "http://127.0.0.1:11434/v1";

      # Wire odysseus to the companion services declared below.
      CHROMADB_HOST = "127.0.0.1";
      CHROMADB_PORT = "8100";
      SEARXNG_INSTANCE = "http://127.0.0.1:8888";
    };

    # environmentFile = "/run/secrets/odysseus.env";
  };

  # SearXNG via the upstream nixpkgs module.
  services.searx = {
    enable = true;
    settings = {
      server = {
        bind_address = "127.0.0.1";
        port = 8888;
        # Set to a random value via the module's environmentFile in
        # real deployments; do NOT keep secrets in nix files.
        secret_key = "change-me-or-set-via-environmentFile";
      };
      search.formats = [
        "html"
        "json"
      ];
    };
  };

  # ChromaDB container — no nixpkgs module exists for it.
  virtualisation.oci-containers = {
    backend = "podman";
    containers.chromadb = {
      image = "chromadb/chroma:latest";
      ports = [ "127.0.0.1:8100:8000" ];
      volumes = [ "/var/lib/chromadb:/chroma/chroma" ];
      environment = {
        IS_PERSISTENT = "TRUE";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/chromadb 0750 root root - -"
  ];
}
