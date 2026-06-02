# Minimal NixOS deployment: just odysseus listening on loopback.
#
# Pair this with whatever LLM backend you already run (Ollama, vLLM,
# OpenAI). ChromaDB / SearXNG / ntfy are optional — without them the app
# falls back to keyword memory search, DuckDuckGo, and email-only
# reminders respectively.
#
# Apply with:
#   nixos-rebuild switch --flake .#yourhost
# after importing this file from your host's configuration.
{
  imports = [
    # Adjust the path to wherever you've checked out the odysseus flake,
    # or use the flake input directly:
    #   odysseus.nixosModules.default
    ../nix/module.nix
  ];

  services.odysseus = {
    enable = true;

    listen = {
      address = "127.0.0.1";
      port = 7000;
    };

    environment = {
      # Point at whatever local LLM you run.
      LLM_HOST = "127.0.0.1";
      OLLAMA_BASE_URL = "http://127.0.0.1:11434/v1";
    };

    # Optional: secrets like OPENAI_API_KEY or HF_TOKEN.
    # environmentFile = "/run/secrets/odysseus.env";
  };
}
