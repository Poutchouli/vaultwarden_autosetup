#!/usr/bin/env bash
# ============================================================
# invite_user.sh — Créer un compte Vaultwarden à partir d'un username
# ============================================================
# Usage :
#   ./scripts/invite_user.sh <username>
#   ./scripts/invite_user.sh alice
#   ./scripts/invite_user.sh Alice        (normalisé en alice)
#
# Le script :
#   1. Normalise le username (minuscules, caractères autorisés uniquement).
#   2. Génère un email technique <username>@<EMAIL_DOMAIN>.
#   3. Appelle l'endpoint /admin/invite de Vaultwarden.
#
# Variables attendues dans le fichier .env à la racine du projet :
#   VAULTWARDEN_DOMAIN  — URL complète du serveur (ex: https://ma-vault.duckdns.org:8443)
#   ADMIN_TOKEN         — Token en clair pour l'API admin (pas le hash Argon2id)
#   EMAIL_DOMAIN        — Domaine technique (ex: vault.internal)
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"

# --- Chargement du .env ---------------------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Erreur : fichier .env introuvable ($ENV_FILE)." >&2
  exit 1
fi

load_env_var() {
  local var_name="$1"
  local value
  value=$(grep -E "^${var_name}=" "$ENV_FILE" | head -1 | cut -d'=' -f2-)
  # Supprimer les guillemets éventuels
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  echo "$value"
}

VAULTWARDEN_DOMAIN="$(load_env_var VAULTWARDEN_DOMAIN)"
ADMIN_TOKEN="$(load_env_var ADMIN_TOKEN)"
EMAIL_DOMAIN="$(load_env_var EMAIL_DOMAIN)"

if [[ -z "$VAULTWARDEN_DOMAIN" ]]; then
  echo "Erreur : VAULTWARDEN_DOMAIN non défini dans .env." >&2
  exit 1
fi
if [[ -z "$ADMIN_TOKEN" ]]; then
  echo "Erreur : ADMIN_TOKEN non défini dans .env." >&2
  exit 1
fi
if [[ -z "$EMAIL_DOMAIN" ]]; then
  EMAIL_DOMAIN="vault.internal"
fi

# --- Validation de l'argument ---------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage : $0 <username>" >&2
  exit 1
fi

RAW_USERNAME="$1"

# --- Normalisation du username ---------------------------------------------
# Minuscules, uniquement a-z 0-9 . - _
USERNAME=$(echo "$RAW_USERNAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]//g')

if [[ -z "$USERNAME" ]]; then
  echo "Erreur : le username '$RAW_USERNAME' ne contient aucun caractère valide (a-z, 0-9, . - _)." >&2
  exit 1
fi

if [[ ${#USERNAME} -lt 2 ]]; then
  echo "Erreur : le username normalisé '$USERNAME' est trop court (minimum 2 caractères)." >&2
  exit 1
fi

EMAIL="${USERNAME}@${EMAIL_DOMAIN}"

echo "Username : $USERNAME"
echo "Email technique : $EMAIL"
echo "Serveur : $VAULTWARDEN_DOMAIN"
echo ""

# --- Appel à l'API /admin/invite -------------------------------------------
# Note : ADMIN_TOKEN ici doit être le token en clair (pas le hash Argon2id
# utilisé dans docker-compose). Si vous avez configuré un mot de passe admin
# simple, utilisez-le directement. Sinon, connectez-vous au panneau /admin
# dans le navigateur et récupérez le cookie de session.

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

HTTP_CODE=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
  -X POST "${VAULTWARDEN_DOMAIN}/admin/invite" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"${EMAIL}\"}" \
  --cookie <(curl -s -c - -X POST "${VAULTWARDEN_DOMAIN}/admin" \
    -d "token=${ADMIN_TOKEN}" | grep -v "^#"))

RESPONSE=$(cat "$TMPFILE" 2>/dev/null || echo "")

case "$HTTP_CODE" in
  200)
    echo "Compte créé avec succès pour '$USERNAME'."
    echo "L'utilisateur peut maintenant se connecter à ${VAULTWARDEN_DOMAIN}"
    echo "avec l'identifiant : $EMAIL"
    ;;
  409)
    echo "Erreur : le username '$USERNAME' (email: $EMAIL) existe déjà." >&2
    exit 1
    ;;
  401|403)
    echo "Erreur : authentification admin refusée. Vérifiez ADMIN_TOKEN dans .env." >&2
    exit 1
    ;;
  *)
    echo "Erreur inattendue (HTTP $HTTP_CODE)." >&2
    if [[ -n "$RESPONSE" ]]; then
      echo "Réponse serveur : $RESPONSE" >&2
    fi
    exit 1
    ;;
esac
