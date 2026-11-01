#!/usr/bin/env bash
# Installeert de twee tunnels uit compose.yaml.
set -euo pipefail

fail() {
  printf 'Fout: %s\n' "$*" >&2
  exit 1
}

# Werk vanuit de map van dit script, ongeacht waar het wordt gestart.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
[[ -f compose.yaml ]] || fail 'Plaats install.sh naast compose.yaml.'
[[ -r /dev/tty && -w /dev/tty ]] || fail 'Start dit script in een interactieve terminal.'
command -v docker >/dev/null 2>&1 || fail 'Installeer eerst Docker.'
docker compose version >/dev/null 2>&1 || fail 'Installeer eerst Docker Compose.'
docker info >/dev/null 2>&1 || fail 'Docker is niet bereikbaar. Start Docker en controleer je toegangsrechten.'

printf '\nCloudflared installeren\n\n'

ask_name() {
  local label="$1" default="$2" value
  while true; do
    read -r -p "$label [$default]: " value </dev/tty || fail 'Invoer afgebroken.'
    value="${value:-$default}"
    if [[ "$value" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
      REPLY="$value"
      return
    fi
    printf 'Gebruik letters, cijfers, punten, streepjes of underscores; begin met een letter of cijfer.\n'
  done
}

ask_token() {
  local label="$1" value
  while true; do
    read -r -s -p "$label (invoer verborgen): " value </dev/tty || fail 'Invoer afgebroken.'
    printf '\n' >/dev/tty
    # Alleen tokenkarakters toestaan, zodat .env geen extra regels of expansies bevat.
    if [[ "$value" =~ ^[a-zA-Z0-9_+/=-]+$ ]]; then
      REPLY="$value"
      return
    fi
    printf 'Plak een token zonder spaties of aanhalingstekens, niet de volledige Docker-opdracht.\n'
  done
}

if [[ -e .env || -L .env ]]; then
  [[ -f .env && ! -L .env ]] || fail '.env moet een normaal bestand zijn, geen symlink.'
  printf 'Bestaand .env gevonden. Dit wordt gebruikt en niet overschreven.\n'
else
  printf 'Maak eerst twee tunnels aan in Cloudflare en houd de tokens bij de hand.\n\n'
  ask_name 'Containernaam tunnel 1' 'cloudflared-1'
  name_1="$REPLY"
  while true; do
    ask_name 'Containernaam tunnel 2' 'cloudflared-2'
    name_2="$REPLY"
    [[ "$name_1" != "$name_2" ]] && break
    printf 'De twee containernamen moeten verschillen.\n'
  done
  ask_token 'Token tunnel 1'
  token_1="$REPLY"
  ask_token 'Token tunnel 2'
  token_2="$REPLY"

  # Maak een privébestand en publiceer het zonder een bestaand .env te overschrijven.
  umask 077
  temporary_env="$(mktemp .env.install.XXXXXX)"
  trap 'rm -f -- "$temporary_env"' EXIT
  {
    printf '# Lokaal bestand met tokens. Niet delen of committen.\n'
    printf 'CONTAINER_NAME_1=%s\n' "$name_1"
    printf 'TUNNEL_TOKEN_1=%s\n\n' "$token_1"
    printf 'CONTAINER_NAME_2=%s\n' "$name_2"
    printf 'TUNNEL_TOKEN_2=%s\n' "$token_2"
  } >"$temporary_env"
  ln -- "$temporary_env" .env || fail '.env kon niet veilig worden aangemaakt.'
  rm -f -- "$temporary_env"
  trap - EXIT
  unset token_1 token_2 REPLY
  printf '\n.env aangemaakt; alleen de eigenaar kan het bestand lezen en schrijven.\n'
fi

# Gebruik expliciet deze configuratie en dit env-bestand.
# --quiet voorkomt dat de ingevulde configuratie met tokens wordt afgedrukt.
compose=(docker compose --env-file .env -f compose.yaml)
"${compose[@]}" config --quiet

printf '\nConfiguratie geldig. Containers ophalen en starten? [j/N]: '
read -r answer </dev/tty || fail 'Invoer afgebroken.'
case "$answer" in
  j|J|ja|Ja|y|Y|yes|Yes) ;;
  *) printf 'Voorbereiding afgerond; containers niet gestart.\n'; exit 0 ;;
esac

"${compose[@]}" pull
"${compose[@]}" up -d
"${compose[@]}" ps
printf '\nContainers gestart. Controleer in Cloudflare of beide tunnels verbonden zijn.\n'
printf 'Logs bekijken: docker compose --env-file .env -f compose.yaml logs --tail=100\n'
