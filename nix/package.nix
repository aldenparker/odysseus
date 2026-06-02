{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
  tmux,
  openssh,
  git,
  nodejs,
  appSrc ? ../.,
  version ? "1.0.0",
}:

let
  pythonEnv = python3.withPackages (
    ps: with ps; [
      fastapi
      uvicorn
      python-multipart
      python-dotenv
      httpx
      pydantic
      pydantic-settings
      sqlalchemy
      pypdf
      beautifulsoup4
      charset-normalizer
      numpy
      # chromadb-client (PyPI) is a slim client of chromadb; nixpkgs only ships
      # the full chromadb, which has the same `import chromadb` surface. The
      # extra server deps add closure size but the API is identical.
      chromadb
      fastembed
      youtube-transcript-api
      markdown
      icalendar
      python-dateutil
      caldav
      cryptography
      bcrypt
      mcp
      pyotp
      qrcode
      croniter
      pytest
      pytest-asyncio
    ]
  );

  runtimePath = lib.makeBinPath [
    tmux
    openssh
    git
    nodejs
  ];

  cleanedSrc = lib.cleanSourceWith {
    src = lib.cleanSource appSrc;
    filter =
      path: type:
      let
        baseName = baseNameOf (toString path);
      in
      !(builtins.elem baseName [
        "data"
        "logs"
        "node_modules"
        "result"
        "__pycache__"
        ".env"
        ".venv"
        "venv"
      ])
      && !(lib.hasSuffix ".pyc" baseName)
      && !(lib.hasPrefix "result-" baseName);
  };
in
stdenvNoCC.mkDerivation {
  pname = "odysseus";
  inherit version;
  src = cleanedSrc;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -d $out/libexec/odysseus $out/bin
    cp -r . $out/libexec/odysseus/
    chmod -R u+w $out/libexec/odysseus

    # The app uses cwd-relative paths for its mutable state (data/, logs/).
    # We set PYTHONPATH so imports resolve regardless of cwd, then leave the
    # working directory to the caller (systemd's WorkingDirectory, or the
    # user's shell). The runtime PATH entries cover tools the app shells
    # out to: tmux for Cookbook, ssh for remote ops, npx for Browser MCP.
    install_dir=$out/libexec/odysseus

    makeWrapper ${pythonEnv}/bin/python $out/bin/odysseus-server \
      --add-flags "-m uvicorn app:app" \
      --prefix PYTHONPATH : "$install_dir" \
      --prefix PATH : ${runtimePath}

    # First-run setup. Honours ODYSSEUS_DATA_DIR / ODYSSEUS_LOG_DIR so it
    # can write into a mutable state dir while the install stays read-only.
    makeWrapper ${pythonEnv}/bin/python $out/bin/odysseus-setup \
      --add-flags "$install_dir/setup.py" \
      --prefix PYTHONPATH : "$install_dir" \
      --prefix PATH : ${runtimePath}

    # Dispatcher CLI. scripts/odysseus discovers its odysseus-* siblings via
    # Path(__file__).parent, so they must stay co-located in libexec. Only
    # the dispatcher lands on $PATH; subcommands are reachable as
    # `odysseus mail …`, `odysseus cookbook …`, etc.
    makeWrapper ${pythonEnv}/bin/python $out/bin/odysseus \
      --add-flags "$install_dir/scripts/odysseus" \
      --prefix PYTHONPATH : "$install_dir" \
      --prefix PATH : ${runtimePath}

    runHook postInstall
  '';

  passthru = {
    inherit pythonEnv;
  };

  meta = with lib; {
    description = "Self-hosted AI workspace (chat, agents, RAG, email, calendar)";
    homepage = "https://github.com/aldenparker/odysseus";
    license = licenses.mit;
    mainProgram = "odysseus-server";
    platforms = platforms.linux;
  };
}
