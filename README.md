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
```

Si vous n'utilisez pas le port HTTPS standard 443, l'URL dans `VAULTWARDEN_DOMAIN` doit inclure le port.
Le port défini dans `CADDY_HTTPS_PORT` doit être le même que celui utilisé dans `VAULTWARDEN_DOMAIN`.

### 2. Générer un hash pour l'ADMIN_TOKEN

```bash
docker run --rm -it vaultwarden/server /vaultwarden hash
```

Copiez le résultat dans `ADMIN_TOKEN` du fichier `.env`.

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

Cette page rappelle comment créer un compte via l'interface web Vaultwarden puis quoi renseigner dans l'extension Bitwarden, avec l'URL du serveur affichée automatiquement à partir de `VAULTWARDEN_DOMAIN`.

## Configuration des extensions Bitwarden

Vous pouvez soit envoyer directement la page guide aux utilisateurs, soit leur communiquer les étapes ci-dessous.

1. Installez l'extension Bitwarden dans votre navigateur
2. Avant de vous connecter, cliquez sur l'icône **engrenage** (paramètres)
3. Dans **URL du serveur**, entrez la valeur définie dans `VAULTWARDEN_DOMAIN`
4. Si vous utilisez un port HTTPS non standard, gardez bien le port dans l'URL, par ex. `https://ma-vault.duckdns.org:8443`
5. Enregistrez, puis créez votre compte ou connectez-vous

## Administration

Tant que `SIGNUPS_ALLOWED=true`, les utilisateurs peuvent créer leur compte depuis l'interface web Vaultwarden. Le guide utilisateur est disponible à l'adresse `VAULTWARDEN_DOMAIN/guide`, par ex. `https://ma-vault.duckdns.org:8443/guide`.

Accédez au panneau d'administration à partir de `VAULTWARDEN_DOMAIN`, par ex. `https://ma-vault.duckdns.org:8443/admin`

Entrez le mot de passe choisi lors de la génération du hash.

### Après création de tous les comptes utilisateurs

Modifiez `.env` :

```env
SIGNUPS_ALLOWED=false
```

Puis redémarrez :

```bash
docker compose down && docker compose up -d
```

## Structure du projet

```text
├── .env                 # Variables de configuration locales (ignoré par Git)
├── .env.example         # Modèle sans secret à versionner
├── docker-compose.yml   # Orchestration des services
├── Caddyfile            # Configuration du reverse proxy
├── caddy/
│   └── Dockerfile       # Build Caddy avec plugin Duck DNS
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
