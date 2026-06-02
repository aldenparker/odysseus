# src/constants.py
"""Application-wide constants and configuration values."""
import os

APP_VERSION = "0.9.1"

# Base paths. BASE_DIR / STATIC_DIR point at the install tree (the code
# directory), so they stay __file__-relative — fine for a read-only install
# because they're only read, never written.
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
STATIC_DIR = os.path.join(BASE_DIR, "static")
# DATA_DIR is overridable via ODYSSEUS_DATA_DIR for read-only installs (e.g.
# Nix store, immutable containers). Falls back to "data" (cwd-relative), which
# matches the project's other `Path("data/...")` literals — every relative
# write resolves against the process's working directory.
DATA_DIR = os.environ.get("ODYSSEUS_DATA_DIR", "data")

# Data file paths
SESSIONS_FILE = os.path.join(DATA_DIR, "sessions.json")
MEMORY_FILE = os.path.join(DATA_DIR, "memory.json")
MEMORY_DOC = os.path.join(DATA_DIR, "memory_doc.md")
PERSONAL_DIR = os.path.join(DATA_DIR, "personal_docs")
RUNBOOK_DIR = os.path.join(PERSONAL_DIR, "runbook")
UPLOAD_DIR = os.path.join(DATA_DIR, "uploads")
FEATURES_FILE = os.path.join(DATA_DIR, "features.json")
SETTINGS_FILE = os.path.join(DATA_DIR, "settings.json")

# API Configuration
MAX_CONTEXT_MESSAGES = 90
REQUEST_TIMEOUT = 20
OPENAI_COMPAT_PATH = "/v1/chat/completions"

# Environment variables with defaults
DEFAULT_HOST = os.getenv("LLM_HOST", "localhost")
LLM_HOSTS = [h.strip() for h in os.getenv("LLM_HOSTS", "").split(",") if h.strip()]
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
SEARXNG_INSTANCE = os.getenv('SEARXNG_INSTANCE', 'http://localhost:8080')


# Cleanup configuration
CLEANUP_ENABLED = os.getenv("CLEANUP_ENABLED", "True").lower() == "true"
CLEANUP_INTERVAL_HOURS = int(os.getenv("CLEANUP_INTERVAL_HOURS", "24"))

# Default parameters
DEFAULT_TEMPERATURE = 1.0
DEFAULT_MAX_TOKENS = 0
