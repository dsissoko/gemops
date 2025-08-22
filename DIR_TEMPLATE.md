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

