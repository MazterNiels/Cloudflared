# Cloudflared

Docker Compose-configuratie voor één of meerdere Cloudflare-tunnels, met voorbeeldconfiguratie en installatie-instructies.

De meegeleverde configuratie draait twee tunnelcontainers in één Compose-project. Iedere container gebruikt een eigen token en kan verbinding maken met een tunnel in een ander Cloudflare-account. Zo kun je bijvoorbeeld privé en zakelijk gescheiden beheren op dezelfde NAS of server.

## Benodigdheden

- Docker met Docker Compose.
- Een Cloudflare-account. Beide tunnels mogen in hetzelfde account of in verschillende accounts staan.
- Voor openbare hostnames: een domein binnen hetzelfde Cloudflare-account als de bijbehorende tunnel.
- Applicaties die vanuit de tunnelcontainers bereikbaar zijn.

## Bestanden

| Bestand | Doel | In Git |
| --- | --- | --- |
| `compose.yaml` | Containers, verplichte variabelen en loginstellingen | Ja |
| `.env.example` | Voorbeeld met uitleg en lege tokenvelden | Ja |
| `.env` | Je eigen containernamen en echte tokens | Nee |
| `.gitignore` | Sluit lokale omgevingsbestanden uit | Ja |
| `LICENSE` | MIT-licentie van deze configuratie | Ja |
| `README.md` | Installatie en beheer | Ja |

## 1. Repository downloaden

```bash
git clone https://github.com/MazterNiels/Cloudflared.git
cd Cloudflared
```

Je kunt de bestanden ook downloaden en in een projectmap op je NAS plaatsen.

## 2. Cloudflare-tunnels aanmaken

1. Open het [Cloudflare-dashboard](https://dash.cloudflare.com/) en selecteer het juiste account.
2. Open het overzicht van Cloudflare Tunnels. De menunamen kunnen verschillen; zoek onder **Networking → Tunnels** of binnen **Zero Trust → Networks**.
3. Maak een tunnel van het type **Cloudflared** en geef deze een herkenbare naam.
4. Kies **Docker** als installatieomgeving.
5. Kopieer alleen de waarde achter `--token` uit de installatieopdracht.
6. Herhaal dit voor de tweede tunnel, eventueel in een ander account.

Je hoeft de getoonde Docker-opdracht niet uit te voeren: Compose start de containers.

## 3. Omgevingsvariabelen invullen

Maak naast `compose.yaml` een kopie van het voorbeeldbestand:

```bash
cp .env.example .env
```

Vul in `.env` voor beide tunnels een unieke containernaam en het bijbehorende token in:

```dotenv
# Tunnel 1
CONTAINER_NAME_1=VUL_HIER_EEN_NAAM_IN
TUNNEL_TOKEN_1=VUL_HIER_HET_TOKEN_VAN_TUNNEL_1_IN

# Tunnel 2
CONTAINER_NAME_2=VUL_HIER_EEN_NAAM_IN
TUNNEL_TOKEN_2=VUL_HIER_HET_TOKEN_VAN_TUNNEL_2_IN
```

De containernamen moeten uniek zijn op de Docker-host. De woorden `prive` en `zakelijk` zijn voorbeelden en kun je aanpassen.

Compose leest `.env` bij het starten en vult de variabelen in de YAML in. Iedere container krijgt uitsluitend zijn eigen token doorgegeven als `TUNNEL_TOKEN`.

Alle vier de variabelen zijn verplicht. Ontbreekt een waarde of is deze leeg, dan stopt Compose met een foutmelding. Een ingevuld maar ongeldig token wordt pas bij het verbinden door Cloudflare geweigerd.

Bewaar `.env` buiten Git. De `.gitignore` hoort dit te bevatten:

```gitignore
.env
.env.*
!.env.example
```

Publiceer alleen `.env.example` zonder echte tokens. Als een token is uitgelekt, roteer het in Cloudflare en werk `.env` bij. Beperk de toegang tot `.env` en Docker-beheer tot bevoegde gebruikers.

## 4. Project starten

Voer vanuit de projectmap uit:

```bash
docker compose up -d
```

Gebruik je het Docker-beheer van een NAS, maak dan een Compose-project met deze bestanden. Zorg dat `.env` naast `compose.yaml` staat en dat het beheerprogramma de variabelen daaruit inleest. Ondersteunt het dat niet, voer de vier variabelen dan in via de projectinstellingen.

Controleer de containers:

```bash
docker compose ps
```

Bekijk de logs:

```bash
docker compose logs --tail=100
```

Controleer ook in Cloudflare of beide tunnels verbonden zijn.

## 5. Applicaties bereikbaar maken

Open de gewenste tunnel in Cloudflare en voeg een **Published application route** of **Public hostname** toe.

| Instelling | Voorbeeld |
| --- | --- |
| Subdomein | `app` |
| Domein | `example.com` |
| Servicetype | `HTTP` |
| Service-URL | `192.168.1.100:8080` |

Vervang het voorbeeldadres door het lokale IP-adres van je server en de gepubliceerde applicatiepoort. Gebruik HTTPS als de achterliggende applicatie dat vereist.

`localhost` verwijst vanuit de tunnelcontainer naar die container zelf. Voor verbinding via een Docker-servicenaam moeten de tunnel en applicatie een Docker-netwerk delen.

Je beheert hostnames en routes in Cloudflare; `compose.yaml` beheert de containers. Stel voor toepassingen die niet openbaar bedoeld zijn ook toegangsbeveiliging in, bijvoorbeeld Cloudflare Access.

## Configuratie

- **Projectnaam:** `cloudflared`.
- **Servicenamen:** `cloudflared-1` en `cloudflared-2`. Deze gebruik je in Compose-opdrachten, ook als je de containernamen wijzigt.
- **Herstartbeleid:** `unless-stopped` herstart containers na uitval, tenzij je ze zelf hebt gestopt.
- **Image:** `cloudflare/cloudflared:latest`. Nieuwe images worden toegepast wanneer je ze ophaalt en de containers bijwerkt.
- **Logs:** de driver `local` roteert per container maximaal drie bestanden van 10 MB, vóór eventuele compressie.
- **Metadata:** `x-metadata` documenteert het project en wordt niet automatisch als containerlabels opgeslagen. De versie daarin betreft deze configuratie, niet de Cloudflared-image.

## Beheer

### Bijwerken

```bash
git pull
docker compose pull
docker compose up -d
```

Gebruik `git pull` alleen als je de repository met Git hebt gedownload. Controleer bij configuratiewijzigingen of je `.env` nieuwe variabelen nodig heeft.

### Gewijzigde naam of token toepassen

Werk `.env` bij en maak de betreffende container opnieuw aan:

```bash
docker compose up -d --force-recreate cloudflared-1
```

Gebruik `cloudflared-2` voor de tweede tunnel.

### Logs van één tunnel volgen

```bash
docker compose logs --tail=100 -f cloudflared-1
```

### Stoppen

```bash
docker compose down
```

Dit verwijdert de tunnels en routes in Cloudflare niet.

## Aantal tunnels aanpassen

De standaardconfiguratie vereist beide tunnels.

- **Eén tunnel:** verwijder de service `cloudflared-2` uit `compose.yaml`. De variabelen voor tunnel 2 zijn dan niet meer nodig.
- **Extra tunnel:** kopieer een service, geef deze een unieke servicenaam en gebruik nieuwe variabelen, bijvoorbeeld `CONTAINER_NAME_3` en `TUNNEL_TOKEN_3`. Voeg deze ook toe aan `.env` en, zonder echt token, aan `.env.example`.

## Problemen oplossen

| Probleem | Controleer |
| --- | --- |
| Compose meldt een ontbrekende variabele | Of `.env` wordt ingelezen en alle vier de waarden zijn ingevuld |
| Containernaam is al in gebruik | Of de gekozen naam uniek is op de Docker-host |
| Tunnel verbindt niet | Token, containerlogs en uitgaand netwerkverkeer naar Cloudflare |
| Tunnel is verbonden, maar de applicatie niet bereikbaar | Service-URL, poort, protocol en netwerkbereikbaarheid |

## Documentatie

- [Cloudflare Tunnel instellen](https://developers.cloudflare.com/tunnel/get-started/)
- [Cloudflared bijwerken](https://developers.cloudflare.com/tunnel/guides/update-cloudflared/)
- [Docker Compose-variabelen](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)
- [Docker-logdriver local](https://docs.docker.com/engine/logging/drivers/local/)

## Auteur

Deze configuratie is gemaakt en wordt onderhouden door [MazterNiels](https://github.com/MazterNiels).

Suggesties of verbeteringen? Open gerust een issue of pull request in deze repository.
