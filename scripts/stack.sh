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

Pilote une stack Docker Compose v2 avec un minimum d’ergonomie :
  - --env ENV  ⇒ injecte --env-file .env.ENV
  - Globales Compose en passthrough (ex: -p, -f, --profile, --env-file)
  - Hooks: hooks.d/*-{pre|post}-{all|start|stop|down|restart}.sh
  - -d (dry-run) : affiche hooks & commande, n’exécute rien

Options :
  --env ENV     Fichier .env.ENV (défaut: dev)
  -d            Dry-run
  -h, --help    Cette aide

Comportement :
  - Sans -f/--file, exige docker-compose.yml ou compose.yaml dans le répertoire courant.
  - --env n’empêche pas d’ajouter d’autres --env-file ; Docker tranche en cas de doublon.
  - Ordre des hooks : pre-all → pre-<cmd> → [docker] → post-all → post-<cmd>.

Sous-commandes :
  start   = docker compose up -d …
  stop    = docker compose stop …
  down    = docker compose down …
  restart = stop puis up -d

Exemples :
  stack --env dev start -- --build api worker
  stack --env prod down -- --volumes --remove-orphans
  stack -d --env prod -p myproj -f docker-compose.prod.yml start -- --build

Pré-requis :
  - Fichier Compose présent (ou -f/--file)
  - .env.ENV correspondant à --env

Codes de sortie :
  0  succès (ou dry-run OK)
  2  erreur d’usage (cmd manquante, --env sans valeur)
  3  compose introuvable (sans -f/--file)
  4  .env.ENV introuvable
  *  code du hook ou de docker compose si échec d’exécution
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

# --- Log exécutable ---
echo "dir=${CALL_DIR} | env=${ENV_NAME} | compose=${COMPOSE_DESC}"
echo -n "exec: docker compose"
printf ' %q' "${GLOBAL_OPTS[@]}"
echo -n " ${CMD}"
if ((${#PASSTHRU[@]})); then
  printf ' %q' "${PASSTHRU[@]}"
fi
echo

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
    log "docker compose up -d ${PASSTHRU[*]}"
    docker compose "${GLOBAL_OPTS[@]}" up   -d "${PASSTHRU[@]}"
    run_hooks post start
    ;;
  stop)
    run_hooks pre  stop
    log "docker compose stop ${PASSTHRU[*]}"
    docker compose "${GLOBAL_OPTS[@]}" stop    "${PASSTHRU[@]}"
    run_hooks post stop
    ;;
  down)
    run_hooks pre  down
    log "docker compose down ${PASSTHRU[*]}"
    docker compose "${GLOBAL_OPTS[@]}" down    "${PASSTHRU[@]}"
    run_hooks post down
    ;;
  restart)
    run_hooks pre  restart
    log "docker compose stop ${PASSTHRU[*]}"
    docker compose "${GLOBAL_OPTS[@]}" stop    "${PASSTHRU[@]}"
    log "docker compose up -d ${PASSTHRU[*]}"
    docker compose "${GLOBAL_OPTS[@]}" up   -d "${PASSTHRU[@]}"
    run_hooks post restart
    ;;
esac
