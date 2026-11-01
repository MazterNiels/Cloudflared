# Cloudflared

Docker Compose-configuratie voor één of meerdere Cloudflare-tunnels, met voorbeeldconfiguratie en installatie-instructies.

De meegeleverde `compose.yaml` bevat standaard één tunnel. Met `install.sh` kies je zelf hoeveel tunnels je wilt configureren. Iedere tunnel draait in een eigen container en kan bij een ander Cloudflare-account horen.

## Benodigdheden

- Docker met Docker Compose en toegang tot de Docker-engine.
- Bash voor het installatiescript. Op Windows kun je Git Bash gebruiken, met Docker Desktop actief.
- Eén of meerdere tunnels in Cloudflare met bijbehorende tokens.
- Voor openbare hostnames: een domein binnen hetzelfde Cloudflare-account als de bijbehorende tunnel.
- Een applicatie die vanuit de tunnelcontainer bereikbaar is.

## Bestanden

| Bestand | Doel | In Git |
| --- | --- | --- |
| `compose.yaml` | Standaardconfiguratie met één tunnel; lokaal aangepast door het script | Ja, zonder tokens |
| `.env.example` | Voorbeeld met uitleg en lege waarden | Ja |
| `install.sh` | Interactieve configuratie en installatie | Ja |
| `.env` | Lokale containernamen en echte tokens | Nee |
| `.env.backup.*` | Back-ups van eerdere configuratiebestanden | Nee |
| `.gitignore` | Sluit omgevingsbestanden en tijdelijke bestanden uit | Ja |
| `LICENSE` | MIT-licentie van deze configuratie | Ja |
| `README.md` | Installatie en beheer | Ja |

## Voorbereiding

Download de repository als ZIP of gebruik Git:

```bash
git clone https://github.com/MazterNiels/Cloudflared.git
cd Cloudflared
```

Maak vervolgens voor iedere gewenste tunnel een Cloudflare Tunnel aan:

1. Open het [Cloudflare-dashboard](https://dash.cloudflare.com/) en selecteer het juiste account.
2. Open het overzicht van Cloudflare Tunnels. De menunamen kunnen verschillen; zoek onder **Networking → Tunnels** of binnen **Zero Trust → Networks**.
3. Maak een tunnel van het type **Cloudflared** en geef deze een herkenbare naam.
4. Kies **Docker** als installatieomgeving.
5. Kopieer alleen de waarde achter `--token` uit de installatieopdracht.

Herhaal dit voor extra tunnels, eventueel in andere accounts. Je hoeft de getoonde Docker-opdracht niet uit te voeren.

## Installatie met het script

Open een Bash-terminal in de projectmap en voer uit:

```bash
bash install.sh
```

Op een NAS kun je hiervoor via SSH verbinden. Heeft je gebruiker alleen via `sudo` toegang tot Docker, gebruik dan:

```bash
sudo bash install.sh
```

Op Windows gebruik je bijvoorbeeld **Open Git Bash here** in de projectmap.

Het script:

1. Controleert Docker en Docker Compose.
2. Vraagt hoeveel tunnels je wilt configureren, van 1 tot en met 99.
3. Vraagt per tunnel een unieke containernaam en het token. Tokeninvoer wordt verborgen.
4. Biedt bestaande namen en tokens aan voor hergebruik.
5. Bouwt `compose.yaml` en `.env` op voor het gekozen aantal tunnels en controleert de configuratie.
6. Maakt back-ups van bestaande bestanden voordat het ze vervangt.
7. Vraagt of je de images wilt ophalen en de containers wilt starten.

Het script maakt geen tunnels aan in Cloudflare; die moeten vooraf bestaan. Het controleert de configuratiestructuur, maar de geldigheid van tokens blijkt pas bij het verbinden.

**Het script vervangt de volledige lokale `compose.yaml` en `.env`.** Handmatige wijzigingen worden daarbij niet overgenomen, behalve herkende containernamen en tokens. Ook als je bij de laatste vraag niet start, zijn de nieuwe bestanden al opgeslagen.

Het script maakt nieuwe bestanden met beperkte Unix-rechten. Op Windows wordt de daadwerkelijke toegang ook bepaald door de Windows-maprechten.

## Handmatige installatie

Voor installatie zonder script kopieer je `.env.example` naar `.env`, naast `compose.yaml`:

```bash
cp .env.example .env
```

Vul de waarden in:

```dotenv
CONTAINER_NAME_1=cloudflared-1
TUNNEL_TOKEN_1=VUL_HIER_JE_TUNNELTOKEN_IN
```

Beide waarden zijn verplicht. De containernaam moet uniek zijn op de Docker-host.

Start het project vanuit de projectmap:

```bash
docker compose up -d
```

Voor extra tunnels kopieer je het serviceblok in `compose.yaml` en wijzig je de servicenaam en beide variabelen naar een nieuw nummer. Voeg de bijbehorende waarden ook aan `.env` toe.

### Via het Docker-scherm van een NAS

1. Maak via het bestandsbeheer een projectmap, bijvoorbeeld `/volume2/docker/cloudflared`.
2. Plaats je ingevulde `.env` in die map.
3. Maak in de Docker-app een nieuw Compose-project met de naam `cloudflared`.
4. Selecteer de projectmap als opslaglocatie.
5. Importeer of plak de inhoud van je `compose.yaml`.
6. Start het project via **Deploy** of de overeenkomstige knop.

Het NAS-beheerprogramma moet de variabelen uit `.env` inlezen. Als het dit niet ondersteunt, gebruik dan de beschikbare projectinstellingen voor omgevingsvariabelen of installeer via de terminal.

Dit scherm voert `install.sh` niet uit. De YAML moet hier al het gewenste aantal tunnels bevatten. Je kunt de bestanden ook lokaal met het script voorbereiden, zonder de containers te starten, en daarna naar de NAS kopiëren.

## Applicaties toevoegen

Open de gewenste tunnel in Cloudflare en voeg een **Published application route** of **Public hostname** toe.

| Instelling | Voorbeeld |
| --- | --- |
| Subdomein | `app` |
| Domein | `example.com` |
| Servicetype | `HTTP` |
| Service-URL | `192.168.1.100:8080` |

Gebruik het lokale IP-adres van je NAS of server en de gepubliceerde applicatiepoort. Kies HTTPS als je applicatie dat vereist.

`localhost` verwijst vanuit de tunnelcontainer naar die container zelf. Voor verbinding via een Docker-servicenaam moeten beide containers een Docker-netwerk delen.

Domeinen en routes beheer je in Cloudflare. Stel voor toepassingen die niet openbaar bedoeld zijn ook toegangsbeveiliging in, bijvoorbeeld Cloudflare Access.

## Configuratie en beveiliging

- Het Compose-project heet standaard `cloudflared`.
- Services heten `cloudflared-1`, `cloudflared-2`, enzovoort. Gebruik deze namen in Compose-opdrachten, ook als de containernamen anders zijn.
- Iedere container krijgt alleen zijn eigen token als `TUNNEL_TOKEN`.
- `restart: unless-stopped` zorgt voor herstart na uitval, tenzij je de container zelf hebt gestopt.
- De logdriver `local` bewaart per container maximaal drie bestanden van 10 MB, vóór eventuele compressie.
- `x-metadata` documenteert de configuratie; het versienummer staat los van de Cloudflared-image.

Gebruik deze `.gitignore`:

```gitignore
.env
.env.*
!.env.example
.compose.install.*
```

Commit geen tokens of back-ups. Beperk toegang tot `.env` en Docker-beheer. Roteer een token in Cloudflare als het is uitgelekt. `.gitignore` verwijdert geen bestanden die al door Git worden gevolgd.

## Beheer

Voer onderstaande opdrachten uit vanuit de projectmap.

### Status en logs

```bash
docker compose ps
docker compose logs --tail=100
```

Controleer ook in Cloudflare of de tunnels verbonden zijn. Logs van één tunnel volgen:

```bash
docker compose logs --tail=100 -f cloudflared-1
```

### Containerimages bijwerken

```bash
docker compose pull
docker compose up -d
```

De tag `latest` wordt pas bijgewerkt wanneer je een nieuwe image ophaalt en de container opnieuw aanmaakt.

### Repository bijwerken

Het installatiescript wijzigt het door Git gevolgde `compose.yaml`. Daardoor kan `git pull` bij latere wijzigingen een conflict melden. Bewaar je lokale configuratie en vergelijk deze met de nieuwe repositoryversie; overschrijf lokale wijzigingen niet blindelings.

### Naam, token of aantal tunnels wijzigen

Start het script opnieuw om de configuratie opnieuw op te bouwen:

```bash
bash install.sh
```

Bestaande waarden kun je met Enter behouden.

Je kunt ook `.env` handmatig aanpassen en de betreffende container opnieuw aanmaken:

```bash
docker compose up -d --force-recreate cloudflared-1
```

Als je minder tunnels kiest, verwijdert het script eerder gestarte extra containers niet automatisch. Controleer deze in Docker en stop of verwijder ze indien gewenst.

### Stoppen

```bash
docker compose down
```

Dit verwijdert de tunnels en routes in Cloudflare niet. Eerder achtergebleven containers die niet meer in de huidige YAML staan, worden met deze opdracht niet automatisch verwijderd.

## Problemen oplossen

| Probleem | Controleer |
| --- | --- |
| Bash via PowerShell geeft een WSL-fout | Open Git Bash en voer het script daar uit |
| Docker niet bereikbaar | Of Docker actief is en je gebruiker toegang heeft |
| Een variabele ontbreekt | Of `.env` wordt ingelezen en de gevraagde waarde is ingevuld |
| Een servicenaam is dubbel gedefinieerd | Of elk serviceblok een uniek nummer heeft |
| Containernaam al in gebruik | Of de gekozen naam uniek is op de Docker-host |
| Tunnel verbindt niet | Token, containerlogs en uitgaand netwerkverkeer |
| Tunnel verbonden, applicatie onbereikbaar | Service-URL, poort, protocol en netwerkbereikbaarheid |

## Documentatie

- [Cloudflare Tunnel instellen](https://developers.cloudflare.com/tunnel/get-started/)
- [Cloudflared bijwerken](https://developers.cloudflare.com/tunnel/guides/update-cloudflared/)
- [Docker Compose-variabelen](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)
- [Docker-logdriver local](https://docs.docker.com/engine/logging/drivers/local/)

## Auteur

Deze configuratie is gemaakt en wordt onderhouden door [MazterNiels](https://github.com/MazterNiels).

Suggesties of verbeteringen? Open gerust een issue of pull request in deze repository.

## Licentie

Deze configuratie en documentatie zijn beschikbaar onder de MIT License. Zie [LICENSE](LICENSE).

Cloudflared zelf behoudt zijn [eigen licentie](https://github.com/cloudflare/cloudflared/blob/master/LICENSE).