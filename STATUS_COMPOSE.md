# status_compose

[`status_compose.sh`](./scripts/status_compose.sh)  
Affiche rapidement **l’état d’un projet Docker Compose** (containers, health, mémoire, logs) en filtrant par **label** `com.docker.compose.project`.

---

## 🧭 Fonctionnement

- **Paramètre unique (optionnel)** : `--project <nom>` ou `-p <nom>`  
  → cible directement le projet Docker Compose voulu.
- **Sans paramètre** : un **menu console** apparaît pour **sélectionner** le projet (navigation **aux flèches** avec `fzf`, sinon fallback `select` Bash).  
- Zéro `.env` requis : la détection s’appuie sur les **labels runtime** déjà présents sur les conteneurs.

---

## ⚙️ Usage

```bash
status_compose --help
```

```
Usage: status_compose [--project <nom>] [--help]

- --project <nom>  : cible un projet Docker Compose précis
- sans paramètre    : menu console pour sélectionner le projet

Affiche pour le projet sélectionné :
  1) Conteneurs actifs (table)
  2) Healthcheck par conteneur
  3) Mémoire conteneurs (docker stats)
  4) Mémoire système (free -h)
  5) Derniers logs (10 lignes)
```

### Exemples

```bash
# 1) Sélection interactive du projet (menu console)
status_compose

# 2) Cibler explicitement un projet
status_compose --project traefik
status_compose -p supabase
```

---

## ✅ Prérequis

- **Docker** (avec le plugin `docker compose`)
- **Utilitaires système** : `free` (paquet `procps`) et `awk` (généralement déjà présents)
- **Pour un menu “flèches” inline** : `fzf` recommandé (sinon, fallback `select` Bash)
  - Installation : `sudo apt-get install -y fzf` (Debian/Ubuntu)

> Astuce : `Esc` ou `Ctrl‑C` annule la sélection `fzf` proprement.

---

## 🖨️ Exemple de sortie (extrait)

```text
📦 Projet sélectionné : traefik

📦 Conteneurs actifs :
NAMES              STATUS                 PORTS
traefik            Up 10 days (healthy)   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp, 0.0.0.0:8080->8080/tcp
certbot            Up 10 days (healthy)   80/tcp, 443/tcp
whoami             Up 10 days             80/tcp

🧪 Healthcheck :
🔹 traefik → ✅ healthy
🔹 certbot → ✅ healthy
🔹 whoami → ❓ no healthcheck defined

🧠 Mémoire conteneurs :
NAME      MEM USAGE / LIMIT
traefik   90.2MiB / 15.4GiB
certbot   34.1MiB / 15.4GiB

🧠 Mémoire système :
               total        used        free      shared  buff/cache   available
Mem:    Total=15.4Gi Used=3.2Gi Free=10.1Gi Available=12.0Gi
Swap:   Total=2.0Gi  Used=0B    Free=2.0Gi

🧾 Derniers logs (10 lignes) :

🔸 traefik :
...

🔸 certbot :
...
```

---

## 🧩 Notes d’implémentation

- Le script filtre **uniquement** les conteneurs du projet choisi via  
  `--filter label=com.docker.compose.project=<nom>`.
- Si **aucun** projet n’est actif, le script l’indique et s’arrête.
- Si **un seul** projet est détecté, il est sélectionné automatiquement.
- Si `fzf` est absent ou si la sortie n’est pas un terminal interactif (TTY), le script
  bascule sur un **menu `select` Bash**.
