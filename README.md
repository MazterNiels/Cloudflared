# Cloudflared

Docker Compose-configuratie voor één of meerdere Cloudflare-tunnels, met afzonderlijke omgevingsbestanden per tunnel.

Gebruik deze opzet op een NAS, server of andere Docker-host om applicaties via Cloudflare Tunnel bereikbaar te maken. Iedere tunnel draait in een eigen container en kan aan een ander Cloudflare-account gekoppeld zijn.

## Benodigdheden

- Docker met Docker Compose.
- Een Cloudflare-account.
- Voor openbare hostnames: een domein binnen hetzelfde Cloudflare-account als de tunnel.
- Een tunnel met een eigen token voor iedere container.
- Een applicatie die vanuit de tunnelcontainer bereikbaar is.

## Bestandsstructuur

```text
compose.yaml
.env.example
.gitignore
LICENSE
README.md
```

Maak daarnaast op je Docker-host een omgevingsbestand per tunnel:

```text
.env.prive
.env.zakelijk
```

De namen `prive` en `zakelijk` zijn voorbeelden. Pas ze aan je eigen situatie aan.

**De echte omgevingsbestanden blijven buiten Git.**

## 1. Tunnels aanmaken

1. Open het [Cloudflare-dashboard](https://dash.cloudflare.com/) en selecteer het juiste account.
2. Open het overzicht van Cloudflare Tunnels. Zoek onder **Networking → Tunnels** of binnen **Zero Trust → Networks**.
3. Maak een tunnel van het type **Cloudflared**.
4. Geef de tunnel een herkenbare naam.
5. Kies **Docker** als installatieomgeving.
6. Kopieer uitsluitend het token achter `--token` uit de getoonde opdracht.
7. Herhaal dit voor iedere extra tunnel, eventueel binnen een ander account.

## 2. Omgevingsbestanden maken

Zet dit in `.env.example`:

```dotenv
TUNNEL_TOKEN=
```

Maak in dezelfde map als `compose.yaml` een kopie voor iedere tunnel:

```bash
cp .env.example .env.prive
cp .env.example .env.zakelijk
```

Vul in ieder bestand het bijbehorende token in:

```dotenv
TUNNEL_TOKEN=vervang_dit_door_het_tunnel_token
```

Gebruik deze inhoud voor `.gitignore`:

```gitignore
.env
.env.*
!.env.example
```

Commit geen echte tokens. `.gitignore` verwijdert geen bestanden die al door Git worden gevolgd. Is een token gepubliceerd, roteer het dan in Cloudflare en werk het lokale omgevingsbestand bij.

## 3. Docker Compose configureren

Plaats dit in `compose.yaml`:

```yaml
services:
  cloudflared-prive:
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel --no-autoupdate run
    env_file:
      - .env.prive

  cloudflared-zakelijk:
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel --no-autoupdate run
    env_file:
      - .env.zakelijk
```

`env_file` geeft iedere container zijn eigen `TUNNEL_TOKEN`. Je hoeft het token niet ook in `command` of `environment` op te nemen.

### Eén tunnel gebruiken

Verwijder de tweede service en maak alleen het omgevingsbestand voor de eerste service aan.

### Extra tunnels toevoegen

Kopieer een service, geef deze een unieke naam en verwijs naar een eigen omgevingsbestand.

## 4. Starten

Voer vanuit de projectmap uit:

```bash
docker compose up -d
```

Op een NAS kun je dezelfde configuratie via het Docker-beheer als Compose-project starten. Zorg dat de omgevingsbestanden in de projectmap beschikbaar zijn.

Controleer de containers:

```bash
docker compose ps
```

Bekijk de logs:

```bash
docker compose logs --tail=100
```

Controleer ook in Cloudflare of de tunnels verbonden zijn.

## 5. Applicaties toevoegen

Open de gewenste tunnel in Cloudflare en voeg een **Published application route** of **Public hostname** toe.

| Instelling | Voorbeeld |
| --- | --- |
| Subdomein | `app` |
| Domein | `example.com` |
| Servicetype | `HTTP` |
| Service-URL | `192.168.1.100:8080` |

Vervang het voorbeeldadres door het lokale IP-adres van je server en de gepubliceerde poort van je applicatie. Gebruik HTTPS wanneer de achterliggende applicatie dat vereist.

### Docker-netwerk

`localhost` verwijst vanuit een tunnelcontainer naar die container zelf.

Gebruik voor een applicatie op je Docker-host het lokale IP-adres en de gepubliceerde applicatiepoort. Voor verbinding via een Docker-servicenaam moeten de tunnel en applicatie een Docker-netwerk delen.

### Routes en toegang

Domeinen en routes beheer je bij deze opzet in Cloudflare. De YAML beheert de containers.

Een tunnel maakt een applicatie bereikbaar. Stel voor toepassingen die niet openbaar bedoeld zijn ook toegangsbeveiliging in, bijvoorbeeld Cloudflare Access.

## Beheer

### Bijwerken

```bash
docker compose pull
docker compose up -d
```

`latest` volgt de beschikbare imageversie wanneer je deze ophaalt. Updates worden met bovenstaande opdrachten toegepast.

Voor een vaste versie vervang je `latest` door een bestaande versietag.

### Een gewijzigd token toepassen

Werk het betreffende omgevingsbestand bij en maak de container opnieuw aan:

```bash
docker compose up -d --force-recreate cloudflared-prive
```

Vervang de servicenaam wanneer je een andere tunnel bijwerkt.

### Logs van één tunnel bekijken

```bash
docker compose logs --tail=100 -f cloudflared-prive
```

### Stoppen

```bash
docker compose down
```

Dit verwijdert de tunnels en routes in Cloudflare niet.

## Problemen oplossen

| Probleem | Controleer |
| --- | --- |
| Tunnel niet verbonden | Token, containerlogs en uitgaand netwerkverkeer naar Cloudflare |
| Tunnel verbonden, applicatie onbereikbaar | Service-URL, poort, protocol en bereikbaarheid vanuit het Docker-netwerk |
| Omgevingsbestand ontbreekt | Bestandsnaam en pad ten opzichte van `compose.yaml` |
| Verkeerd account of domein | Of de tunnel en het domein binnen hetzelfde Cloudflare-account staan |
Deze configuratie en documentatie zijn beschikbaar onder de MIT License. Zie [LICENSE](LICENSE).

Cloudflared zelf valt onder de licentie van het [Cloudflare-project](https://github.com/cloudflare/cloudflared).
