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
├── infra/                 # Provisioning et configuration bas niveau (par provider/env)
│   └── gcp/
│       └── dev/
│           ├── pulumi/    # Code Pulumi
│           ├── cloud-init/ # Templates cloud-init
│           └── scripts/   # Scripts liés à l'environnement
│
├── platform/              # Composants techniques (DB, Kafka, etc.)
│   └── timescale/
│       ├── compose/       # Fichiers docker-compose
│       ├── config/        # Config spécifique (SQL, conf, etc.)
│       ├── scripts/       # start.sh, stop.sh, backup.sh...
│       ├── volumes/       # Volumes persistants ou init data
│       ├── .env           # Variables d'environnement (par env)
│       ├── README.md
│       └── NOTES.md
│
├── application/           # Microservices ou apps dockerisées
│   └── app1/
│       ├── compose/
│       ├── config/
│       ├── scripts/
│       ├── volumes/
│       ├── .env
│       ├── README.md
│       └── NOTES.md
│
├── ops/                   # Super-scripts pour orchestrer l'ensemble
│   ├── bootstrap.sh
│   ├── status.sh
│   ├── backup-all.sh
│   └── restore-all.sh
│
├── localbin/              # Outils locaux réutilisables (install.sh, uninstall.sh, helpers...)
│   ├── install.sh
│   ├── uninstall.sh
│   └── utils.sh
│
├── README.md
└── .gitignore
```

```gitignore
# === Node / JS ===
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnpm-debug.log*

# === Python ===
__pycache__/
*.py[cod]
*.pyo
*.pyd
*.pdb
*.egg-info/
.eggs/

# === IDE / Editor ===
.vscode/
.idea/
*.swp
*.swo

# === System files ===
.DS_Store
Thumbs.db

# === Logs ===
*.log
logs/
*.out

# === Docker ===
**/docker-compose.override.yml
**/compose.override.yml
.docker/
docker-data/

# === Secrets ===
# On ignore les .env normaux
*.env
.env
**/.env

# On garde les versions chiffrées
!*.env.crypt

# === Backups / Dumps ===
*.bak
*.sql
*.dump
*.tar
*.gz

# === Build outputs ===
dist/
build/
target/
coverage/
htmlcov/

# === Local bin utils ===
localbin/*.tmp
localbin/*.bak
```

---

**Pré-requis**

- Unix shell standard (bash, zsh, etc.)  
- `openssl` ou équivalent pour chiffrer/déchiffrer les fichiers `.env.crypt`  

---

