#!/usr/bin/env bash
# stack.sh — Wrapper Compose v2 minimal + strict
# - Convention: 1er arg optionnel = --env ENV  → injecte  --env-file .env.ENV
# - Globales Compose: tout ce qui précède la sous-commande est passé tel quel
# - Sous-commandes supportées: start | stop | down | restart
# - En cas d’erreur: warning + usage + exit non-zéro (rien n’est exécuté)
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: stack [--env ENV] [-d] [COMPOSE_GLOBALS…] {start|stop|down|restart} [args sous-commande…]

But : Piloter Docker Compose v2 avec env + hooks + passthrough (+ .env.stack optionnel)

Options :
  --env ENV     Injecte --env-file .env.ENV (défaut: dev)
  -d            Dry-run (affiche hooks + commande effective)
  -h, --help    Cette aide

Comportement :
  - Sans -f/--file, exige docker-compose.yml ou compose.yaml dans le répertoire courant.
  - Les options Compose AVANT la sous-commande sont transmises telles quelles (-p, -f, --profile…).
  - Hooks exécutés si présents : hooks.d/*-{pre|post}-{all|start|stop|down|restart}.sh
  - .env.stack (optionnel) :
      * COMPOSE_INCLUDE=f1.yml,f2.yml,…  → pré-préfixe ces fichiers avec -f
      * Les -f passés par l’utilisateur arrivent après → ils ont la priorité
      * Si vous utilisez COMPOSE_INCLUDE, listez aussi la base (ex: docker-compose.yml)
  - Rappel Docker Compose : si vous utilisez au moins un -f, vous devez lister TOUS les fichiers voulus
    (ex: docker-compose.yml, docker-compose.override.yml, puis vos overrides).

Sous-commandes :
  start   = docker compose up -d …
  stop    = docker compose stop …
  down    = docker compose down …
  restart = stop puis up -d

Codes de sortie :
  0  succès (ou dry-run OK)
  2  erreur d’usage (cmd manquante, --env sans valeur)
  3  fichier compose introuvable / fichier listé dans .env.stack introuvable*
  4  fichier .env.ENV manquant
  *  code du hook ou de docker compose en cas d’échec

Exemples :
  stack --env dev start
  stack --env prod -p myproj -f docker-compose.prod.yml start -- --build
  # avec .env.stack (COMPOSE_INCLUDE=docker-compose.yml,docker-compose.override.yml,docker-compose.override.inject.yml)
  stack --env dev start
EOF
}

warn() { printf '⚠️  %s\n' "$*" >&2; }

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }

ENV_NAME="dev"
# Dry-run flag
DRYRUN=0

# Options "maison" en tête : -d (dry-run), --env ENV
while (($#)); do
  case "${1:-}" in
    -h|--help)
      usage; exit 0 ;;     # ← affiche l’aide et quitte proprement  
    -d) DRYRUN=1; shift ;;
    --env)
      [[ $# -ge 2 ]] || { warn "--env requiert une valeur"; usage; exit 2; }
      ENV_NAME="$2"; shift 2 ;;
    start|stop|down|restart)
      break ;;  # on laisse la suite au parseur global
    *)
      break ;;  # tout le reste sera traité comme GLOBALS/PASSTHRU
  esac
done

# Split: GLOBALS (avant sous-commande) / CMD / PASSTHRU (après)
GLOBALS=()
CMD=""
PASSTHRU=()
while (($#)); do
  case "$1" in
    start|stop|down|restart) CMD="$1"; shift; PASSTHRU=("$@"); break ;;
    *) GLOBALS+=("$1"); shift ;;
  esac
done

# Commande obligatoire
if [[ -z "$CMD" ]]; then
  warn "Commande manquante (start|stop|down|restart)."
  usage; exit 2
fi

CALL_DIR="$(pwd -P)"

# Si pas de -f/--file dans GLOBALS, exiger un fichier compose standard
has_file_opt=0
for t in "${GLOBALS[@]}"; do
  [[ "$t" == "-f" || "$t" == "--file" ]] && { has_file_opt=1; break; }
done
COMPOSE_DESC="(via -f/--file)"
if (( has_file_opt == 0 )); then
  if   [[ -f "docker-compose.yml" ]]; then COMPOSE_DESC="docker-compose.yml"
  elif [[ -f "compose.yaml"      ]]; then COMPOSE_DESC="compose.yaml"
  else
    warn "Fichier Compose introuvable (docker-compose.yml ou compose.yaml) dans: ${CALL_DIR}"
    usage; exit 3
  fi
fi

# .env.<ENV> strict
ENV_FILE=".env.${ENV_NAME}"
if [[ ! -f "$ENV_FILE" ]]; then
  warn "Fichier d'environnement manquant: ${ENV_FILE} (répertoire: ${CALL_DIR})"
  usage; exit 4
fi

# --- Hooks (hooks.d/*-{pre|post}-{all|CMD}.sh) ---
HOOKS_DIR="hooks.d"
list_hooks() { # $1=phase pre|post, $2=cmd
  [[ -d "$HOOKS_DIR" ]] || return 0
  shopt -s nullglob
  for f in "$HOOKS_DIR"/*-"$1"-all.sh "$HOOKS_DIR"/*-"$1"-"$2".sh; do
    echo "hook:$1:$2 -> $f"
  done
}
run_hooks() { # $1=phase, $2=cmd
  if (( DRYRUN )); then
    list_hooks "$1" "$2"
  else
    [[ -d "$HOOKS_DIR" ]] || return 0
    shopt -s nullglob
    for f in "$HOOKS_DIR"/*-"$1"-all.sh "$HOOKS_DIR"/*-"$1"-"$2".sh; do
      echo "hook:$1:$2 -> $f"
      bash "$f"
    done
  fi
}

# Injection --env-file (placée avant les globales utilisateur)
GLOBAL_OPTS=( --env-file "$ENV_FILE" "${GLOBALS[@]}" )

# --- .env.stack : pré-préfixe des -f via COMPOSE_INCLUDE (user garde la priorité) ---
STACK_ENV_FILE=".env.stack"
if [[ -f "$STACK_ENV_FILE" ]]; then
  COMPOSE_INCLUDE=""
  # Lire uniquement COMPOSE_INCLUDE (ignorer commentaires & lignes vides)
  while IFS='=' read -r k v; do
    [[ -z "${k// }" || "${k#\#}" != "$k" ]] && continue
    [[ "$k" == "COMPOSE_INCLUDE" ]] && COMPOSE_INCLUDE="${v//[$'\r']/}"
  done < "$STACK_ENV_FILE"

  if [[ -n "${COMPOSE_INCLUDE// }" ]]; then
    IFS=',' read -ra inc <<< "$COMPOSE_INCLUDE"

    # Normalise, vérifie, et construit la liste à préfixer
    PREPEND=()
    for f in "${inc[@]}"; do
      f="$(echo "$f" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [[ -z "$f" ]] && continue
      if [[ -f "$f" ]]; then
        PREPEND+=( -f "$f" )
      else
        warn "Fichier listé dans .env.stack introuvable: $f"   # remplacer par 'exit 3' si tu veux strict
      fi
    done

    if [[ ${#PREPEND[@]} -gt 0 ]]; then
      # Préfixage : les -f utilisateur (déjà dans GLOBALS) restent à la fin → priorité user
      GLOBAL_OPTS=( --env-file "$ENV_FILE" "${PREPEND[@]}" "${GLOBALS[@]}" )
      echo "compose-files(+stack, prepend): ${COMPOSE_INCLUDE}"
    fi
  fi
fi

# --- Log exécutable ---
if [[ "$CMD" != "restart" ]]; then
  echo "dir=${CALL_DIR} | env=${ENV_NAME} | compose=${COMPOSE_DESC}"
  echo -n "exec: docker compose"
  printf ' %q' "${GLOBAL_OPTS[@]}"
  echo -n " ${CMD}"
  if ((${#PASSTHRU[@]})); then
    printf ' %q' "${PASSTHRU[@]}"
  fi
  echo
fi

# Dry-run: affiche contexte, hooks "would run", commande effective; n'exécute rien
if (( DRYRUN )); then
  list_hooks pre  "$CMD"
  list_hooks post "$CMD"
  exit 0
fi

# Exécution
case "$CMD" in
  start)
    run_hooks pre  start
    GO=""
    log "docker compose ${GO}up -d ${PASSTHRU[*]}"
    docker compose "${GLOBAL_OPTS[@]}" up   -d "${PASSTHRU[@]}"
    run_hooks post start
    ;;
  stop)
    run_hooks pre  stop
    GO=""
    log "docker compose ${GO}stop ${PASSTHRU[*]}"
    docker compose "${GLOBAL_OPTS[@]}" stop    "${PASSTHRU[@]}"
    run_hooks post stop
    ;;
  down)
    run_hooks pre  down
    GO=""
    log "docker compose ${GO}down ${PASSTHRU[*]}"
    docker compose "${GLOBAL_OPTS[@]}" down    "${PASSTHRU[@]}"
    run_hooks post down
    ;;
  restart)
    # 👉 Pas d'auto-appel : on exécute "stop" puis "start" inline avec les mêmes GLOBAL_OPTS/PASSTHRU

    if (( DRYRUN )); then
      echo "would: stop ${PASSTHRU[*]}"
      list_hooks pre  stop
      list_hooks post stop
      echo "would: start ${PASSTHRU[*]}"
      list_hooks pre  start
      list_hooks post start
      exit 0
    fi

    # --- STOP ---
    run_hooks pre  stop
    GO=""; printf -v GO '%q ' "${GLOBAL_OPTS[@]}"
    log "docker compose ${GO}stop ${PASSTHRU[*]}"
    docker compose "${GLOBAL_OPTS[@]}" stop "${PASSTHRU[@]}"
    run_hooks post stop

    # --- START ---
    run_hooks pre  start
    GO=""; printf -v GO '%q ' "${GLOBAL_OPTS[@]}"
    log "docker compose ${GO}up -d ${PASSTHRU[*]}"
    docker compose "${GLOBAL_OPTS[@]}" up -d "${PASSTHRU[@]}"
    run_hooks post start
    ;;
esac
