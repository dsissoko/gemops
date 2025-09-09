#!/bin/bash
set -euo pipefail

# === 🧾 Aide ===
show_help() {
  cat <<EOF
Usage: status_compose [--env-file /chemin/.env.*] [--list all|svc1,svc2,...] [--help]

Ce script affiche :
  - Le statut des conteneurs actifs
  - Leur état de santé (healthcheck)
  - L'utilisation mémoire
  - Les derniers logs

Options :
  --env-file PATH      Fichier d'environnement à passer à 'docker compose'
  --list all           Affiche les informations pour tous les conteneurs Docker
  --list svc1,svc2     Liste personnalisée de services à surveiller
  --help, -h           Affiche cette aide

Comportement par défaut :
  - Si un fichier docker-compose.yml est présent dans le répertoire courant
    **et qu'une stack Compose y est active**, les services détectés sont utilisés automatiquement.
  - Sinon, l'option --list est requise.
EOF
}

# === ⚙️ Variables par défaut ===
SHOW_ALL=false
SERVICES=()
ESSENTIAL_LOGS=()
ENV_FILE=""

# === 🎛️ Parsing des arguments ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      LIST_ARG="${2:-}"
      if [[ -z "$LIST_ARG" ]]; then
        echo "❌ Veuillez spécifier une valeur après --list (ex: all ou svc1,svc2)"
        exit 1
      fi
      if [[ "$LIST_ARG" == "all" ]]; then
        SHOW_ALL=true
      else
        IFS=',' read -ra SERVICES <<< "$LIST_ARG"
        ESSENTIAL_LOGS=("${SERVICES[@]}")
      fi
      shift 2
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    --env-file)
      ENV_FILE="${2:-}"
      [[ -z "$ENV_FILE" ]] && { echo "❌ --env-file requiert un chemin"; exit 1; }
      [[ ! -f "$ENV_FILE" ]] && { echo "❌ Fichier introuvable: $ENV_FILE"; exit 1; }
      shift 2
      ;;
    *)
      echo "❌ Option inconnue : $1"
      show_help
      exit 1
      ;;
  esac
done

# === 📦 Détection des services Docker Compose ===
if [[ "${#SERVICES[@]}" -eq 0 && "$SHOW_ALL" == false ]]; then
  if [[ -n "${ENV_FILE}" ]]; then
    if docker compose --env-file "${ENV_FILE}" ps --format '{{.Name}}' &>/dev/null; then
      mapfile -t DEFAULT_SERVICES < <(docker compose --env-file "${ENV_FILE}" ps --format '{{.Name}}')
    else
      echo "❌ Aucun conteneur détecté via Docker Compose dans le répertoire courant (avec ${ENV_FILE})."
      echo "ℹ️ Lance d'abord la stack, ou utilise --list pour cibler les conteneurs."
      exit 1
    fi
  else
    if docker compose ps --format '{{.Name}}' &>/dev/null; then
      mapfile -t DEFAULT_SERVICES < <(docker compose ps --format '{{.Name}}')
    else
      echo "❌ Aucun conteneur détecté via Docker Compose dans le répertoire courant."
      echo "ℹ️ Utilise --env-file /chemin/.env.* ou --list."
      exit 1
    fi
  fi

  SERVICES=("${DEFAULT_SERVICES[@]}")
  ESSENTIAL_LOGS=("${DEFAULT_SERVICES[@]}")
fi

# === 1. Conteneurs actifs ===
echo -e "📦 Conteneurs actifs :"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# === 2. Healthcheck ===
echo -e "\n🧪 Healthcheck :"
TARGET_SERVICES=()
if $SHOW_ALL; then
  ALL_CONTAINERS=($(docker ps -aq))
  if [ ${#ALL_CONTAINERS[@]} -eq 0 ]; then
    echo "⚠️ Aucun conteneur trouvé pour le healthcheck."
  else
    mapfile -t TARGET_SERVICES < <(printf "%s\n" "${ALL_CONTAINERS[@]}" | xargs -n1 docker inspect --format '{{.Name}}' | sed 's|^/||')
  fi
else
  TARGET_SERVICES=("${SERVICES[@]}")
fi

for svc in "${TARGET_SERVICES[@]}"; do
  if docker inspect "$svc" &>/dev/null; then
    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$svc")
    case "$health" in
      healthy)   echo "🔹 $svc → ✅ healthy" ;;
      unhealthy) echo "🔹 $svc → ❌ unhealthy" ;;
      *)         echo "🔹 $svc → ❓ no healthcheck defined" ;;
    esac
  else
    echo "🔹 $svc → ⛔️ container not found"
  fi
done

# === 3. Mémoire conteneurs ===
echo -e "\n🧠 Mémoire conteneurs :"
RUNNING_CONTAINERS=()
if $SHOW_ALL; then
  ALL_RUNNING=($(docker ps -q))
  if [ ${#ALL_RUNNING[@]} -gt 0 ]; then
    mapfile -t RUNNING_CONTAINERS < <(printf "%s\n" "${ALL_RUNNING[@]}" | xargs -n1 docker inspect --format '{{.Name}}' | sed 's|^/||')
  fi
else
  for svc in "${SERVICES[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${svc}$"; then
      RUNNING_CONTAINERS+=("$svc")
    fi
  done
fi

if [ ${#RUNNING_CONTAINERS[@]} -gt 0 ]; then
  docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" "${RUNNING_CONTAINERS[@]}"
else
  echo "⚠️ Aucun conteneur actif ciblé"
fi

# === 4. Mémoire système ===
echo -e "\n🧠 Mémoire système :"
free -h | awk 'NR==1{print $0} NR==2{print "Mem:  \tTotal="$2, "Used="$3, "Free="$4, "Available="$7} NR==3{print "Swap: \tTotal="$2, "Used="$3, "Free="$4}'

# === 5. Logs essentiels ===
echo -e "\n🧾 Derniers logs (10 lignes) :"
LOG_TARGETS=()
if $SHOW_ALL; then
  ALL_CONTAINERS=($(docker ps -aq))
  if [ ${#ALL_CONTAINERS[@]} -eq 0 ]; then
    echo "⚠️ Aucun conteneur trouvé pour les logs."
  else
    mapfile -t LOG_TARGETS < <(printf "%s\n" "${ALL_CONTAINERS[@]}" | xargs -n1 docker inspect --format '{{.Name}}' | sed 's|^/||')
  fi
else
  LOG_TARGETS=("${ESSENTIAL_LOGS[@]}")
fi

for svc in "${LOG_TARGETS[@]}"; do
  echo -e "\n🔸 $svc :"
  if docker ps -a --format '{{.Names}}' | grep -q "^$svc$"; then
    docker logs --tail=10 "$svc" || echo "⚠️ Aucun log"
  else
    echo "⚠️ Service ou conteneur introuvable"
  fi
done
