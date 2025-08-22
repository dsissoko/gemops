# Directory Template

Une arborescence claire et agnostique pour organiser l'infrastructure, la plateforme et les applications.  
Il sépare les scripts spécifiques aux composants et les opérations globales, afin de rester lisible et maintenable à long terme.  

---

**Usage**

- Chaque composant est isolé dans son propre répertoire (`platform/` ou `application/`), avec ses propres scripts, configurations et volumes.  
- Les scripts locaux réutilisables sont placés dans `localbin/` et ajoutés au `PATH`.  
- Les opérations globales ou transverses (ex. déploiement complet, backup global, status cluster) sont placées dans `ops/`.  
- L'organisation est volontairement agnostique vis-à-vis des outils : que ce soit `Pulumi`, `cloud-init`, `docker-compose`, `kubectl`, `skaffold`, `portainer` ou autres, l'arborescence reste stable.  
- Les fichiers `.env` sont gérés par environnement (`.env.dev`, `.env.prod`) et peuvent être chiffrés (`.env.crypt`) si nécessaire.  

Arborescence type :  

```
.
dir_template/
├── README.md                        # Documentation globale du template
│
├── infrastructure/                  # Provisionnement infra (cloud, VM, réseau)
│   ├── README.md
│   └── provider1/                   # Fournisseur cloud spécifique (ex: GCP, OCI, AWS)
│       ├── dev/                     # Environnement de développement
│       │   ├── pulumi/              # IaC Pulumi pour déploiement infra
│       │   │   └── Pulumi.dev.py    # Stack Pulumi pour l’environnement dev
│       │   └── init/                # Scripts d’initialisation serveur (cloud-init & shell)
│       │       ├── cloud-init.yaml  # Config cloud-init pour bootstrap VM
│       │       ├── install-docker.sh # Installation de Docker
│       │       ├── harden.sh        # Sécurisation système (hardening)
│       │       ├── setup-wireguard.sh # Configuration VPN WireGuard
│       │       └── NOTES.md         # Notes spécifiques dev
│       └── prod/                    # Environnement de production
│           ├── pulumi/
│           │   └── Pulumi.prod.py   # Stack Pulumi pour prod
│           └── init/
│               ├── cloud-init.yaml  # Config cloud-init pour bootstrap VM
│               ├── monitoring.sh    # Agent/supervision serveur
│               ├── backup-agent.sh  # Sauvegarde & restauration
│               └── NOTES.md         # Notes spécifiques prod
│
├── platform/                        # Services plateforme communs (DB, cache, broker…)
│   ├── README.md
│   ├── compo1/                      # Exemple composant plateforme 1
│   │   ├── compose/                 # Docker Compose pour ce composant
│   │   │   ├── docker-compose.yml   # Définition des conteneurs
│   │   │   ├── .env.dev.crypt       # Variables d’env cryptées pour dev
│   │   │   └── .env.prod.crypt      # Variables d’env cryptées pour prod
│   │   ├── config/                  # Config spécifique du service
│   │   │   └── custom.conf
│   │   ├── volumes/                 # Données persistées/initialisées
│   │   │   └── init-data.sql
│   │   ├── scripts/                 # Scripts de gestion du composant
│   │   │   ├── start.sh
│   │   │   ├── stop.sh
│   │   │   ├── restart.sh
│   │   │   └── status.sh
│   │   └── NOTES.md
│   │
│   └── compo2/                      # Exemple composant plateforme 2
│       ├── compose/
│       │   ├── docker-compose.yml
│       │   ├── .env.dev.crypt
│       │   └── .env.prod.crypt
│       ├── config/
│       │   └── service.conf
│       ├── volumes/
│       │   └── init/
│       │       └── schema.sql
│       ├── scripts/
│       │   ├── start.sh
│       │   ├── stop.sh
│       │   └── restart.sh
│       └── NOTES.md
│
├── applications/                    # Composants applicatifs (microservices, UI, batch…)
│   ├── README.md
│   ├── compo1/                      # Composant applicatif 1
│   │   ├── compose/
│   │   │   ├── docker-compose.yml
│   │   │   ├── .env.dev.crypt
│   │   │   └── .env.prod.crypt
│   │   ├── config/
│   │   │   └── app.conf
│   │   ├── volumes/
│   │   │   └── init-data.json
│   │   ├── scripts/
│   │   │   ├── start.sh
│   │   │   ├── stop.sh
│   │   │   └── status.sh
│   │   └── NOTES.md
│   │
│   └── compo2/                      # Composant applicatif 2
│       ├── compose/
│       │   ├── docker-compose.yml
│       │   ├── .env.dev.crypt
│       │   └── .env.prod.crypt
│       ├── config/
│       │   └── app.conf
│       ├── volumes/
│       │   └── init/
│       │       └── data.sql
│       ├── scripts/
│       │   ├── start.sh
│       │   ├── stop.sh
│       │   └── restart.sh
│       └── NOTES.md
│
├── ops/                             # Automatisation & orchestration (devops tools)
│   ├── README.md
│   ├── bootstrap.sh                 # Script init global de l’environnement
│   ├── deploy-platform.sh            # Déploiement des composants plateforme
│   ├── deploy-applications.sh        # Déploiement des composants applicatifs
│   └── teardown.sh                   # Suppression/rollback de l’environnement
│
├── localbin/                        # Scripts utilitaires locaux
│   ├── README.md
│   ├── install.sh                    # Installation des binaires locaux
│   ├── uninstall.sh                  # Nettoyage/suppression
│   ├── wait-for.sh                   # Helper pour attendre un service
│   └── logs.sh                       # Helper pour afficher les logs
│
├── README.md                        # Guide racine du projet
└── .gitignore                       # Exclusions Git (env, secrets, binaires…)
```

```gitignore
# === Secrets ===
*.env
.env
**/.env
!*.env.crypt

# === Logs & backups ===
*.log
*.bak
*.sql
*.dump
*.tar
*.gz

# === Python virtualenv ===
venv/
.envrc
__pycache__/
*.pyc
```

---

**Pré-requis**

- Unix shell standard (bash, zsh, etc.)  
- `openssl` ou équivalent pour chiffrer/déchiffrer les fichiers `.env.crypt`  

---

