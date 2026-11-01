#!/usr/bin/env bash
# Interactieve installatie van één of meerdere Cloudflare-tunnels.
set -euo pipefail

fail() {
  printf 'Fout: %s\n' "$*" >&2
  exit 1
}

printf '\n'
printf '============================================================\n'
printf ' Cloudflared — Installatie\n'
printf ' Auteur: MazterNiels\n'
printf ' GitHub: https://github.com/MazterNiels/Cloudflared\n'
printf '============================================================\n'
printf '\n'

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

command -v docker >/dev/null 2>&1 \
  || fail 'Installeer eerst Docker.'

docker compose version >/dev/null 2>&1 \
  || fail 'Installeer eerst Docker Compose.'

docker info >/dev/null 2>&1 \
  || fail 'Docker is niet bereikbaar. Controleer Docker en je toegangsrechten.'

[[ -r /dev/tty && -w /dev/tty ]] \
  || fail 'Gebruik een interactieve Bash-terminal.'

# Lees bestaande waarden zonder het bestand als shellcode uit te voeren.
old_names=()
old_tokens=()
previous_count=0

if [[ -e .env || -L .env ]]; then
  [[ -f .env && ! -L .env ]] \
    || fail '.env moet een normaal bestand zijn.'

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"

    if [[ "$line" =~ ^(CONTAINER_NAME|TUNNEL_TOKEN)_([1-9][0-9]?)=(.*)$ ]]; then
      kind="${BASH_REMATCH[1]}"
      index="${BASH_REMATCH[2]}"
      value="${BASH_REMATCH[3]}"

      # Ondersteun eenvoudige waarden tussen aanhalingstekens.
      if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then
        value="${value:1:${#value}-2}"
      fi

      if [[ "$kind" == CONTAINER_NAME &&
            "$value" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
        old_names[index]="$value"
      elif [[ "$kind" == TUNNEL_TOKEN &&
              "$value" =~ ^[a-zA-Z0-9_+/=-]+$ ]]; then
        old_tokens[index]="$value"
      fi

      if (( index > previous_count )); then
        previous_count="$index"
      fi
    fi
  done < .env

  printf 'Bestaand .env gevonden. Geldige namen en tokens kun je hergebruiken.\n'
fi

printf '\nCloudflared installeren\n'

default_count="$previous_count"
if (( default_count == 0 )); then
  default_count=1
fi

while true; do
  read -r -p \
    "Hoeveel tunnels wil je configureren? [$default_count]: " \
    count </dev/tty || fail 'Invoer afgebroken.'

  count="${count:-$default_count}"

  [[ "$count" =~ ^[1-9][0-9]?$ ]] && break

  printf 'Kies een geheel getal van 1 tot en met 99.\n'
done

printf 'Zorg dat deze tunnels al in Cloudflare bestaan en houd hun tokens bij de hand.\n'

names=()
tokens=()

for ((i=1; i<=count; i++)); do
  printf '\nTunnel %s\n' "$i"
  default_name="${old_names[i]:-cloudflared-$i}"

  while true; do
    read -r -p "Containernaam [$default_name]: " value \
      </dev/tty || fail 'Invoer afgebroken.'

    value="${value:-$default_name}"

    if [[ ! "$value" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
      printf 'Gebruik letters, cijfers, punten, streepjes of underscores; begin met een letter of cijfer.\n'
      continue
    fi

    duplicate=false

    for ((j=1; j<i; j++)); do
      if [[ "${names[j]}" == "$value" ]]; then
        duplicate=true
      fi
    done

    if [[ "$duplicate" == true ]]; then
      printf 'Gebruik voor elke tunnel een andere naam.\n'
      continue
    fi

    names[i]="$value"
    break
  done

  while true; do
    token_prompt='Tunneltoken (invoer verborgen): '

    if [[ -n "${old_tokens[i]:-}" ]]; then
      token_prompt='Tunneltoken (Enter = bestaand token behouden): '
    fi

    read -r -s -p "$token_prompt" value \
      </dev/tty || fail 'Invoer afgebroken.'

    printf '\n' >/dev/tty
    value="${value:-${old_tokens[i]:-}}"

    if [[ "$value" =~ ^[a-zA-Z0-9_+/=-]+$ ]]; then
      tokens[i]="$value"
      break
    fi

    printf 'Plak alleen het token, zonder spaties of de Docker-opdracht.\n'
  done
done

# Controleer de nieuwe configuratie voordat bestaande bestanden wijzigen.
umask 077
temporary_env=''
temporary_compose=''

cleanup() {
  [[ -z "$temporary_env" ]] || rm -f -- "$temporary_env"
  [[ -z "$temporary_compose" ]] || rm -f -- "$temporary_compose"
  return 0
}

trap cleanup EXIT

temporary_env="$(mktemp .env.install.XXXXXX)"
temporary_compose="$(mktemp .compose.install.XXXXXX)"

printf '# Lokaal bestand met tokens. Niet delen of committen.\n' \
  > "$temporary_env"

cat > "$temporary_compose" <<'YAML'
# ============================================================
# Cloudflared - Docker Compose Configuration
# Gegenereerd door install.sh
# ============================================================

name: cloudflared

x-metadata:
  project: "Cloudflared"
  description: "Docker Compose-configuratie voor één of meerdere Cloudflare-tunnels, met voorbeeldconfiguratie en installatie-instructies."
  repository: "https://github.com/MazterNiels/Cloudflared"
  author: "MazterNiels"
  license: "MIT"
  version: "0.1.0"

services:
YAML

for ((i=1; i<=count; i++)); do
  printf '\nCONTAINER_NAME_%s=%s\nTUNNEL_TOKEN_%s=%s\n' \
    "$i" "${names[i]}" "$i" "${tokens[i]}" >> "$temporary_env"

  cat >> "$temporary_compose" <<YAML
  cloudflared-$i:
    container_name: \${CONTAINER_NAME_$i:?Vul CONTAINER_NAME_$i in .env in.}
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel --no-autoupdate run
    environment:
      TUNNEL_TOKEN: \${TUNNEL_TOKEN_$i:?Vul TUNNEL_TOKEN_$i in .env in.}
      TUNNEL_LOGLEVEL: info
    logging:
      driver: local
      options:
        max-size: "10m"
        max-file: "3"
YAML
done

# Toon de ingevulde configuratie met tokens niet in de terminal.
docker compose \
  --env-file "$temporary_env" \
  -f "$temporary_compose" \
  config --quiet

# Maak back-ups voordat bestaande bestanden worden vervangen.
for target in .env compose.yaml; do
  if [[ -e "$target" || -L "$target" ]]; then
    [[ -f "$target" && ! -L "$target" ]] \
      || fail "$target moet een normaal bestand zijn."

    backup="$(mktemp ".env.backup.${target//./_}.XXXXXX")"
    cp -- "$target" "$backup"
    chmod 600 "$backup"

    printf 'Back-up gemaakt: %s (kan tokens bevatten; niet delen).\n' \
      "$backup"
  fi
done

mv -- "$temporary_env" .env
temporary_env=''

mv -- "$temporary_compose" compose.yaml
temporary_compose=''

unset tokens old_tokens value

printf '\n.env en compose.yaml aangemaakt voor %s tunnel(s).\n' "$count"
printf 'Op Windows worden de toegangsrechten ook door de Windows-maprechten bepaald.\n'

if (( count < previous_count )); then
  printf 'Let op: eerder gestarte extra tunnelcontainers worden niet automatisch verwijderd.\n'
fi

compose=(docker compose --env-file .env -f compose.yaml)

read -r -p 'Containers ophalen en starten? [j/N]: ' answer \
  </dev/tty || fail 'Invoer afgebroken.'

case "$answer" in
  j|J|ja|Ja|y|Y|yes|Yes)
    "${compose[@]}" pull
    "${compose[@]}" up -d
    "${compose[@]}" ps
    printf '\nControleer in Cloudflare of alle tunnels verbonden zijn.\n'
    ;;
  *)
    printf 'Configuratie opgeslagen. Containers niet gestart.\n'
    ;;
esac

printf '\nStarten: docker compose --env-file .env -f compose.yaml up -d\n'
printf 'Logs: docker compose --env-file .env -f compose.yaml logs --tail=100\n'