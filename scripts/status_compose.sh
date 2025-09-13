#!/usr/bin/env bash
set -euo pipefail

# === Args ===
PROJECT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project|-p) PROJECT="${2:-}"; shift 2 ;;
    --help|-h)
      cat <<EOF
Usage: status_compose [--project <nom>] [--help]

- --project <nom> : cible un projet Docker Compose précis
- sans paramètre   : menu console pour sélectionner le projet

Affiche pour le projet sélectionné :
  1) Conteneurs actifs (table)
  2) Healthcheck par conteneur
  3) Mémoire conteneurs (docker stats)
  4) Mémoire système (free -h)
  5) Derniers logs (10 lignes)
EOF
      exit 0
      ;;
    *)
      echo "❌ Option inconnue : $1"
      exit 1
      ;;
  esac
done

# === Inventaire des projets (labels Compose) ===
declare -A seen=()
ALL_PROJECTS=()
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  if [[ -z "${seen[$p]+x}" ]]; then
    seen[$p]=1
    ALL_PROJECTS+=("$p")
  fi
done < <(docker ps -a --filter label=com.docker.compose.project \
           --format '{{.Label "com.docker.compose.project"}}')

# === Sélection interactive si --project absent ===
if [[ -z "$PROJECT" ]]; then
  case "${#ALL_PROJECTS[@]}" in
    0) echo "❌ Aucun projet Compose actif détecté."; exit 1 ;;
    1) PROJECT="${ALL_PROJECTS[0]}" ;;
    *)
      if command -v fzf >/dev/null 2>&1 && [ -t 1 ]; then
        PROJECT="$(
          printf '%s\n' "${ALL_PROJECTS[@]}" | fzf \
            --prompt="Projet > " \
            --header="↑/↓ pour naviguer • Entrée pour valider • Échap pour annuler" \
            --height=40% --reverse --border --cycle --no-sort --disabled \
            --preview 'docker ps -a --filter label=com.docker.compose.project={} --format "{{.Names}}\t{{.Status}}"' \
            --preview-window=down,50%
        )"
        [[ -n "$PROJECT" ]] || { echo "Annulé."; exit 1; }
      else
        echo "Projets actifs :"
        select choice in "${ALL_PROJECTS[@]}" "Quitter"; do
          case "$REPLY" in
            $(( ${#ALL_PROJECTS[@]} + 1 ))) echo "Bye."; exit 1 ;;
            *) PROJECT="${choice}"; [[ -n "$PROJECT" ]] && break ;;
          esac
        done
      fi
      ;;
  esac
fi

# === Récup liste des conteneurs du projet ===
mapfile -t PROJECT_CONTAINERS < <(
  docker ps -a \
    --filter "label=com.docker.compose.project=${PROJECT}" \
    --format '{{.Names}}'
)

if [[ ${#PROJECT_CONTAINERS[@]} -eq 0 ]]; then
  echo "⚠️ Aucun conteneur pour le projet '${PROJECT}'."
  exit 0
fi

echo "📦 Projet sélectionné : ${PROJECT}"

# === 1) Conteneurs actifs (du projet) ===
echo -e "\n📦 Conteneurs actifs :"
docker ps \
  --filter "label=com.docker.compose.project=${PROJECT}" \
  --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# === 2) Healthcheck ===
echo -e "\n🧪 Healthcheck :"
for svc in "${PROJECT_CONTAINERS[@]}"; do
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

# === 3) Mémoire conteneurs (running du projet) ===
echo -e "\n🧠 Mémoire conteneurs :"
mapfile -t RUNNING_PROJECT_CONTAINERS < <(
  docker ps \
    --filter "label=com.docker.compose.project=${PROJECT}" \
    --format '{{.Names}}'
)
if [[ ${#RUNNING_PROJECT_CONTAINERS[@]} -gt 0 ]]; then
  docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" "${RUNNING_PROJECT_CONTAINERS[@]}"
else
  echo "⚠️ Aucun conteneur actif dans le projet"
fi

# === 4) Mémoire système ===
echo -e "\n🧠 Mémoire système :"
free -h | awk 'NR==1{print $0} NR==2{print "Mem:  \tTotal="$2, "Used="$3, "Free="$4, "Available="$7} NR==3{print "Swap: \tTotal="$2, "Used="$3, "Free="$4}'

# === 5) Logs essentiels (10 lignes) ===
echo -e "\n🧾 Derniers logs (10 lignes) :"
for svc in "${PROJECT_CONTAINERS[@]}"; do
  echo -e "\n🔸 $svc :"
  if docker ps -a --format '{{.Names}}' | grep -q "^$svc$"; then
    docker logs --tail=10 "$svc" || echo "⚠️ Aucun log"
  else
    echo "⚠️ Service ou conteneur introuvable"
  fi
done
