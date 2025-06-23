#!/usr/bin/env bash

# Dev Container Post-Setup Script
# Description: Configure aliases and developer experience enhancements

set -euo pipefail

# --- Colors ---
CYAN='\033[36m'
GREEN='\033[32m'
BLUE='\033[34m'
RESET='\033[0m'

echo -e "${CYAN}[*] Setting up development environment${RESET}"

# --- Start Docker Daemon (DinD setup) ---
echo -e "${GREEN}[+] Starting Docker daemon${RESET}"
if ! pgrep dockerd > /dev/null; then
  sudo nohup dockerd > /tmp/dockerd.log 2>&1 &
  sleep 5
  echo -e "${BLUE}[i] Docker started successfully${RESET}"
else
  echo -e "${BLUE}[i] Docker already running${RESET}"
fi

# --- Add useful aliases ---
echo -e "${GREEN}[+] Adding development aliases${RESET}"
cat >> "$HOME/.bashrc" << 'EOF'

# === Development Aliases ===
alias ll="ls -la"
alias supa-start="supabase start"
alias supa-stop="supabase stop"
alias supa-db-reset="supabase db reset"
alias supa-db-push="supabase db push"
alias supa-functions-serve="supabase functions serve --env-file supabase/.env"

show_supabase_help() {
  echo
  echo    "╔══════════════════════════════════════════════════════════════════════════════╗"
  echo -e "║                          🚀 \033[36mSupabase Dev Container Commands\033[0m                  ║"
  echo    "╠══════════════════════════════════════════════════════════════════════════════╣"
  echo -e "║  \033[32msupa-start\033[0m           Start local Supabase stack                             ║"
  echo -e "║  \033[32msupa-stop\033[0m            Stop local Supabase stack                              ║"
  echo -e "║  \033[32msupa-db-reset\033[0m        Reset and reapply all migrations                       ║"
  echo -e "║  \033[32msupa-db-push\033[0m         Push schema changes to local DB                        ║"
  echo -e "║  \033[32msupa-functions-serve\033[0m Serve Edge Functions locally (Deno)                    ║"
  echo    "║                                                                              ║"
  echo -e "║  \033[33mTip:\033[0m Use \033[32msupa-help\033[0m to show this message again                               ║"
  echo    "╚══════════════════════════════════════════════════════════════════════════════╝"
  echo
}

alias supa-help="show_supabase_help"

# === Colorful Prompt ===
PS1='\[\033[38;5;39m\]\u\[\033[0m\]@\[\033[38;5;42m\]\h\[\033[0m\] \[\033[38;5;244m\]\w\[\033[0m\]\n\$ '


# Show help on interactive terminals
if [[ $- == *i* ]]; then
    show_supabase_help
fi
EOF
