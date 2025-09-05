# stack

[`stack.sh`](./scripts/stack.sh)  
Fin wrapper **Docker Compose v2** pour piloter une stack avec un minimum d’ergonomie (env + hooks + passthrough).

---

**Usage :**  
Lancez vos actions Compose (start/stop/down/restart) avec injection d’un env-file via `--env`, des hooks optionnels, et un mode dry-run.

```shell
$ stack --help
Usage: stack [--env ENV] [-d] [COMPOSE_GLOBALS…] {start|stop|down|restart} [args sous-commande…]

Ce script pilote une stack Docker Compose v2 avec un minimum d’ergonomie :
  - Injection d’environnement via --env ENV  → ajoute --env-file .env.ENV
  - Passage “passthrough” des options Compose globales (ex: -p, -f, --profile, --env-file)
  - Hooks optionnels par stack: hooks.d/*-{pre|post}-{all|start|stop|down|restart}.sh
  - Mode dry-run (-d) : affiche les hooks et la commande effective, n’exécute rien

Options :
  --env ENV            Sélectionne le fichier d’environnement .env.ENV (défaut : dev)
  -d                   Dry-run : affiche les hooks “would run” et la commande, sans exécuter
  -h, --help           Affiche cette aide

Comportement par défaut :
  - Les options globales Compose (avant la sous-commande) sont transmises telles quelles.
    Exemples : -p myproj, -f docker-compose.prod.yml, --profile prod, --env-file .env.prod
  - Si aucune option -f/--file n’est fournie, un fichier Compose standard est requis
    dans le répertoire courant : docker-compose.yml ou compose.yaml.
  - L’option --env n’empêche pas d’ajouter d’autres --env-file ; en cas de doublon,
    c’est Docker Compose qui tranche (ordre des options).
  - Ordre des hooks si présents :
      pre-all → pre-<cmd> → [commande docker] → post-all → post-<cmd>

Sous-commandes :
  start                Équivalent à “docker compose up -d …”
  stop                 “docker compose stop …”
  down                 “docker compose down …”
  restart              stop puis up -d

Exemples :
  stack --env dev start -- --build api worker
  stack --env prod down -- --volumes --remove-orphans
  stack -d --env prod -p myproj -f docker-compose.prod.yml start -- --build
  stack --env prod --env-file .env.extra start        # doublons autorisés, Compose décide
```

**Prérequis :**
- [Docker](https://docs.docker.com/get-docker/) avec `docker compose` (v2)
- Un fichier Compose dans le répertoire courant (`docker-compose.yml` ou `compose.yaml`), sauf usage de `-f/--file`
- Un fichier d’environnement correspondant à `--env` : `.env.dev` (par défaut), `.env.prod`, etc.

**Exemple de sortie (dry-run) :**
```shell
$ stack -d --env prod -p myproj -f docker-compose.prod.yml start -- --build api
exec: docker compose --env-file .env.prod -p myproj -f docker-compose.prod.yml start -- --build api
hook:pre:start  -> hooks.d/10-pre-all.sh
hook:pre:start  -> hooks.d/20-pre-start.sh
hook:post:start -> hooks.d/90-post-all.sh
hook:post:start -> hooks.d/95-post-all.sh
```

**Exemple de sortie (exécution réelle) :**
```shell
$ stack --env dev down -- --volumes --remove-orphans
14:03:11 docker compose down -- --volumes --remove-orphans
[+] Running 3/3
 ✔ Container app-api-1      Removed
 ✔ Container app-db-1       Removed
 ✔ Network app_default      Removed
hook:post:down -> hooks.d/90-post-all.sh
```

**Hooks (optionnels) :**
- Placez des scripts exécutables dans `hooks.d/` :
  - Nommage : `NN-pre|post-<scope>.sh` (ex. `10-pre-all.sh`, `20-pre-start.sh`, `90-post-all.sh`)
  - Scopes : `all`, `start`, `stop`, `down`, `restart`
  - Ordre garanti : `pre-all` → `pre-<cmd>` → **docker compose** → `post-all` → `post-<cmd>`
- Conseils : scripts idempotents, `set -euo pipefail`, logs courts, timeout si besoin.

**Codes de sortie :**
- `0` : succès (ou dry-run OK)
- `2` : erreur d’usage (commande manquante, `--env` sans valeur)
- `3` : fichier Compose introuvable (sans `-f/--file`)
- `4` : fichier `.env.ENV` introuvable
- `*` : code renvoyé par un hook ou par `docker compose` en cas d’échec d’exécution
