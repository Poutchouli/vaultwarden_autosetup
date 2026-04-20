# Vaultwarden - Gestionnaire de mots de passe (LAN)

Déploiement Vaultwarden avec HTTPS automatique via Caddy + Duck DNS, accessible depuis le réseau local.

## Prérequis

- Docker et Docker Compose
- Un compte [Duck DNS](https://www.duckdns.org) avec un sous-domaine créé et pointant vers l'IP LAN du serveur

## Démarrage rapide

### 1. Créer le `.env`

Copiez le modèle puis modifiez le fichier `.env` à la racine du projet :

```bash
cp .env.example .env
```

Valeurs à renseigner dans `.env` :

```env
DUCKDNS_SUBDOMAIN=ma-vault
DUCKDNS_TOKEN=votre-token-duckdns
VAULTWARDEN_DOMAIN=https://ma-vault.duckdns.org:8443
CADDY_HTTP_PORT=8080
CADDY_HTTPS_PORT=8443
CONTACT_EMAIL=admin@example.com
ADMIN_TOKEN=remplacer-par-un-token-admin-fort
EMAIL_DOMAIN=vault.internal
```

Si vous n'utilisez pas le port HTTPS standard 443, l'URL dans `VAULTWARDEN_DOMAIN` doit inclure le port.
Le port défini dans `CADDY_HTTPS_PORT` doit être le même que celui utilisé dans `VAULTWARDEN_DOMAIN`.

### 2. Définir `ADMIN_TOKEN`

```bash
openssl rand -base64 48
```

Copiez le résultat tel quel dans `ADMIN_TOKEN` du fichier `.env`.
N'utilisez pas ici de hash Argon2id si vous voulez conserver le fonctionnement
du script `scripts/invite_user.sh`, qui se connecte au panneau admin avec le
token en clair.

### 3. Lancer les services

```bash
docker compose up -d
```

Le premier démarrage prend quelques minutes (compilation de Caddy + obtention du certificat).

### 4. Vérifier les logs

```bash
docker compose logs -f
```

### 5. Partager le guide utilisateur

Une fois les services démarrés, vous pouvez envoyer cette URL aux utilisateurs :

`VAULTWARDEN_DOMAIN/guide`

Par exemple : `https://ma-vault.duckdns.org:8443/guide`

Cette page rappelle comment se connecter après avoir reçu son compte et quoi renseigner dans l'extension Bitwarden, avec l'URL du serveur affichée automatiquement à partir de `VAULTWARDEN_DOMAIN`.

## Configuration des extensions Bitwarden

Vous pouvez soit envoyer directement la page guide aux utilisateurs, soit leur communiquer les étapes ci-dessous.

1. Installez l'extension Bitwarden dans votre navigateur
2. Avant de vous connecter, cliquez sur l'icône **engrenage** (paramètres)
3. Dans **URL du serveur**, entrez la valeur définie dans `VAULTWARDEN_DOMAIN`
4. Si vous utilisez un port HTTPS non standard, gardez bien le port dans l'URL, par ex. `https://ma-vault.duckdns.org:8443`
5. Enregistrez, puis connectez-vous avec l'identifiant transmis par l'administrateur

## Administration

L'inscription publique est désactivée (`SIGNUPS_ALLOWED=false`). Les comptes sont créés par l'administrateur à partir d'un **nom d'utilisateur** via le script fourni.

Le guide utilisateur est disponible à l'adresse `VAULTWARDEN_DOMAIN/guide`, par ex. `https://ma-vault.duckdns.org:8443/guide`.

Accédez au panneau d'administration à partir de `VAULTWARDEN_DOMAIN/admin`, par ex. `https://ma-vault.duckdns.org:8443/admin`

Entrez le mot de passe choisi lors de la génération du hash.

### Créer un compte utilisateur

Utilisez le script `scripts/invite_user.sh` en passant le nom d'utilisateur souhaité :

```bash
./scripts/invite_user.sh alice
```

Le script :
1. Normalise le username (minuscules, caractères `a-z 0-9 . - _` uniquement)
2. Génère un email technique : `alice@vault.internal`
3. Crée l'invitation via l'API admin de Vaultwarden

L'utilisateur peut ensuite se connecter à Vaultwarden avec l'identifiant `alice@vault.internal` et définir son mot de passe maître.

Le domaine technique (`EMAIL_DOMAIN`) est configurable dans `.env` (par défaut : `vault.internal`).

> **Note :** si un username existe déjà, le script le signale et refuse de créer un doublon.

## Structure du projet

```text
├── .env                 # Variables de configuration locales (ignoré par Git)
├── .env.example         # Modèle sans secret à versionner
├── docker-compose.yml   # Orchestration des services
├── Caddyfile            # Configuration du reverse proxy
├── caddy/
│   └── Dockerfile       # Build Caddy avec plugin Duck DNS
├── scripts/
│   └── invite_user.sh   # Création de compte par username
└── vw-data/             # Données Vaultwarden (à sauvegarder !)
```

## DNS Rebind

Certains routeurs bloquent les domaines qui résolvent vers des IPs privées. Si vous ne pouvez pas accéder au serveur, ajoutez une exception DNS sur votre routeur ou utilisez un DNS local (Pi-hole, etc.).

## Accès LAN-only

Pour un usage uniquement sur le réseau local, le nom `ma-vault.duckdns.org` doit résoudre vers l'IP LAN du serveur, par exemple `192.168.1.68`, et non vers l'IP publique.

Solutions possibles :

1. Ajouter une entrée DNS locale sur le routeur, Pi-hole, AdGuard Home, dnsmasq, etc.
2. Ajouter temporairement une entrée dans le fichier hosts de chaque poste client.

Exemple de correspondance attendue :

192.168.1.68 ma-vault.duckdns.org

Ensuite, utilisez l'URL définie dans `VAULTWARDEN_DOMAIN`, par exemple `https://ma-vault.duckdns.org:8443`.

## Sauvegardes

Sauvegardez régulièrement le dossier `./vw-data/` qui contient la base de données et les fichiers chiffrés.
