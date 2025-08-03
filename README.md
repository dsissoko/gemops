# devops_gem

> *life is a bitch but devops_gem may help*

💎 Scripts Bash pour la vie quotidienne des devops : gestion des containers, monitoring, outils divers.

## 🚀 Scripts inclus

- [`status_compose.sh`](./scripts/status_compose.sh)  
  Affiche rapidement l’état des containers lancés via Docker Compose.

### status_compose

**Usage :**  
Consultez en une commande l’état de vos conteneurs Docker Compose (dans le répertoire courant), d’une liste précise, ou de tous les conteneurs actifs.

```shell
r3edge@devbox:~/compose$ status_compose --help
Usage: status_compose [--list all|svc1,svc2,...] [--help]

Ce script affiche :
  - Le statut des conteneurs actifs
  - Leur état de santé (healthcheck)
  - L'utilisation mémoire
  - Les derniers logs

Options :
  --list all           Affiche les informations pour tous les conteneurs Docker
  --list svc1,svc2     Liste personnalisée de services à surveiller
  --help, -h           Affiche cette aide

Comportement par défaut :
  - Si un fichier docker-compose.yml est présent dans le répertoire courant
    **et qu'une stack Compose y est active**, les services détectés sont utilisés automatiquement.
  - Sinon, l'option --list est requise.
```

**Prérequis :**
- [Docker](https://docs.docker.com/get-docker/) (avec le plugin `docker compose`)
- Utilitaires système : `free` (`procps`) et `awk` (installés par défaut sur 99% des distributions Linux)

**Exemple de sortie :**

```shell
r3edge@devbox:~/compose$ status_compose

📦 Conteneurs actifs :
NAMES                            STATUS                 PORTS
traefik                          Up 10 days (healthy)   0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp, 0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
certbot                          Up 10 days (healthy)   80/tcp, 443/tcp
whoami                           Up 10 days             80/tcp
config-server                    Up 4 weeks (healthy)   0.0.0.0:8889-8890->8889-8890/tcp, [::]:8889-8890->8889-8890/tcp
github-webhook                   Up 4 weeks             0.0.0.0:9000->9000/tcp, [::]:9000->9000/tcp
redpanda-console                 Up 5 weeks             0.0.0.0:9090->8080/tcp, [::]:9090->8080/tcp
redpanda-0                       Up 5 weeks (healthy)   8081-8082/tcp, 0.0.0.0:18081-18082->18081-18082/tcp, [::]:18081-18082->18081-18082/tcp, 9092/tcp, 0.0.0.0:19092->19092/tcp, [::]:19092->19092/tcp, 0.0.0.0:19644->9644/tcp, [::]:19644->9644/tcp
supabase-auth                    Up 5 weeks (healthy)
supabase-meta                    Up 5 weeks (healthy)   8080/tcp
supabase-kong                    Up 5 weeks (healthy)   8000/tcp, 8443-8444/tcp, 10.0.0.1:8001->8001/tcp
supabase-rest                    Up 5 weeks             3000/tcp
supabase-studio                  Up 5 weeks (healthy)   3000/tcp
realtime-dev.supabase-realtime   Up 5 weeks (healthy)
supabase-analytics               Up 5 weeks (healthy)   0.0.0.0:4000->4000/tcp, [::]:4000->4000/tcp
supabase-db                      Up 5 weeks (healthy)   0.0.0.0:5433->5432/tcp, [::]:5433->5432/tcp
supabase-vector                  Up 5 weeks (healthy)

🧪 Healthcheck :
🔹 redpanda-0 → ✅ healthy
🔹 redpanda-console → ❓ no healthcheck defined

🧠 Mémoire conteneurs :
NAME               MEM USAGE / LIMIT
redpanda-0         264.8MiB / 3.729GiB
redpanda-console   342.1MiB / 3.729GiB

🧠 Mémoire système :
               total        used        free      shared  buff/cache   available
Mem:    Total=3.7Gi Used=2.6Gi Free=232Mi Available=1.1Gi
Swap:   Total=1.0Gi Used=1.0Gi Free=0B

🧾 Derniers logs (10 lignes) :

🔸 redpanda-0 :
WARN  2025-08-03 17:30:01,650 [shard 0:main] cluster - feature_manager.cc:318 - A Redpanda Enterprise Edition license
....

🔸 redpanda-console :
{"level":"info","ts":"2025-08-01T18:32:14.876Z","msg":"successfully pulled git repository","repository_url":"https://github.com/redpanda-data/docs","read_files":1}
{"level":"info","ts":"2025-08-01T18:33:14.881Z","msg":"successfully pulled git repository","repository_url":"https://github.com/redpanda-data/docs","read_files":1}
...
```

*D’autres scripts arriveront au fil de l’eau…*

## 📦 Installation

```bash
git clone https://github.com/<ton_user>/devops_gem
cd devops_gem
chmod +x scripts/**/*.sh
```

---

📫 Maintenu par [@dsissoko](https://github.com/dsissoko) – suggestions et étoiles appréciées !
