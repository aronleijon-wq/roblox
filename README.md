# Hinderbana – ett Roblox-obby

En komplett hinderbana (obby) för Roblox, skriven i Luau. Banan byggs av kod när
spelet startar, så du kan börja med en helt tom place och ändra allt i en enda
inställningsfil.

## Vad finns i spelet?

- **10 checkpoints** med 9 hindersektioner emellan: hopp, lavastreck, rörliga
  plattformar, plattformar som försvinner, en klätterstege och snurrande lavabommar.
- **Lavahav** under banan. Ramlar man ner börjar man om vid sin senaste checkpoint.
- **Mynt** att samla. De snurrar och kommer tillbaka efter en stund.
- **Sparade framsteg** (nivå, mynt och vinster) med DataStore, och en topplista
  uppe till höger.
- **HUD** som visar nivå, en förloppsindikator, mynt, meddelanden och en
  "Play again"-knapp när man gått i mål.
- **Fusk-skydd:** checkpoints måste tas i ordning, och all logik körs på servern.

## Kom igång

### 1. Installera verktygen

1. Installera [Roblox Studio](https://create.roblox.com/).
2. Installera [Rokit](https://github.com/rojo-rbx/rokit), en verktygshanterare för
   Roblox-projekt, och kör sedan i den här mappen:
   ```sh
   rokit install
   ```
   Då får du `rojo`, `selene`, `stylua` och `lune` i de versioner projektet använder.
3. Installera Rojo-pluginet i Studio:
   ```sh
   rojo plugin install
   ```

### 2a. Snabbast: bygg en place-fil

```sh
rojo build -o Hinderbana.rbxlx
```

Öppna `Hinderbana.rbxlx` i Roblox Studio och tryck **Play** (F5).

### 2b. Rekommenderat när du utvecklar: synka live med Rojo

1. Starta Rojo-servern i projektmappen:
   ```sh
   rojo serve
   ```
2. Öppna en ny **Baseplate** i Roblox Studio.
3. Gå till fliken **Plugins → Rojo** och klicka **Connect**.
4. Tryck **Play** (F5).

Nu syns alla ändringar du sparar i `src/` direkt i Studio.

> **Obs:** Banan byggs när spelet *startar*, så den syns inte i redigeringsläget,
> bara när du trycker Play.

### 3. Spara spelardata och publicera

DataStore fungerar bara i publicerade spel:

1. **File → Publish to Roblox** för att publicera.
2. **Game Settings → Security → Enable Studio Access to API Services** om du vill
   att det sparas även när du testar i Studio.

Utan det fungerar spelet ändå, men inget sparas, och du får en varning i Output.

## Ändra banan

Nästan allt ställs in i [`src/shared/Config.luau`](src/shared/Config.luau). Banan
består av en lista med sektioner:

```lua
Sections = {
	{ kind = "Jumps", count = 5, gap = 4, rise = 1, sway = 2, platformSize = Vector3.new(6, 1, 6) },
	{ kind = "KillBricks", length = 40, width = 6, strips = 4, stripHeight = 1, stripDepth = 2 },
	{ kind = "Moving", count = 3, gap = 3, travel = 10, platformSize = Vector3.new(6, 1, 6) },
	...
},
```

Lägg till, ta bort eller byt ordning på rader, så blir banan längre, kortare eller
svårare. Efter varje sektion kommer automatiskt en checkpoint, och efter den sista
kommer målet.

| Typ          | Vad det är                                   | Inställningar                                   |
| ------------ | -------------------------------------------- | ----------------------------------------------- |
| `Jumps`      | Hopp mellan plattformar i sicksack           | `count`, `gap`, `rise`, `sway`, `platformSize`  |
| `KillBricks` | Gångbana med lavastreck att hoppa över       | `length`, `width`, `strips`, `stripHeight`, `stripDepth` |
| `Moving`     | Plattformar som åker i sidled                | `count`, `gap`, `travel`, `platformSize`        |
| `Fading`     | Plattformar som försvinner när man står på dem | `count`, `gap`, `platformSize`                |
| `Truss`      | Klätterstege uppåt                           | `gap`, `height` (jämnt tal)                     |
| `Spinner`    | Plattform med en snurrande lavabom           | `size`, `speed`                                 |

En vanlig Roblox-karaktär hoppar ungefär **8 studs** framåt och **7 studs** uppåt,
så håll `gap` under det. Testerna (se nedan) varnar om ett hopp blir omöjligt.

## Bygg egna hinder i Studio

Alla hinder styrs av **taggar**, så du kan också bygga egna delar för hand i Studio.
Markera en del, gå till **Properties → Tags** och lägg till en tagg. Sätt eventuella
attribut under **Properties → Attributes**.

| Tagg             | Beteende                                   | Attribut                                               |
| ---------------- | ------------------------------------------ | ------------------------------------------------------ |
| `KillBrick`      | Dödar den som nuddar                       | –                                                      |
| `Checkpoint`     | Sparar spelarens nivå                      | `Stage` (heltal, **krävs**). Högst nummer = målet.     |
| `Coin`           | Mynt som går att plocka upp                | `Value` (valfritt)                                     |
| `MovingPlatform` | Åker fram och tillbaka                     | `MoveOffset` (Vector3, **krävs**), `MoveTime`, `MovePause` |
| `Spinner`        | Snurrar runt sin egen mittpunkt            | `SpinSpeed`                                            |
| `FadingPlatform` | Försvinner en stund när man står på den    | `FadeTime`, `ReappearTime`                             |

Vill du bygga hela banan själv sätter du `Course.Enabled = false` i Config.

## Projektets struktur

```
src/
  shared/                  -> ReplicatedStorage.Shared (server + klient)
    Config.luau              alla inställningar
  server/                  -> ServerScriptService.Server
    Main.server.luau         startpunkt: bygger banan och tar hand om spelare
    CourseBuilder.luau       bygger banan från Config
    Checkpoints.luau         checkpoints, nivåer och målgång
    Spawner.luau             spawnar spelare vid rätt checkpoint
    Hazards.luau             lava, rörliga, snurrande och försvinnande hinder
    Coins.luau               mynt
    PlayerData.luau          sparar och laddar data + topplistan
    Util.luau                hjälpfunktioner
  client/                  -> StarterPlayer.StarterPlayerScripts.Client
    Hud.client.luau          gränssnittet
    CoinSpinner.client.luau  får mynten att snurra
tests/
  run.luau                 tester som körs utanför Roblox med Lune
default.project.json       talar om för Rojo var allt ska ligga i Roblox
```

## Testa och städa koden

```sh
lune run tests/run.luau   # testar logiken och att alla hopp går att klara
selene src                # hittar vanliga misstag
stylua src tests          # formaterar koden
```

## Idéer på vad du kan bygga härnäst

- **Butik** där man köper speed coil, gravity coil eller trails för sina mynt.
- **"Hoppa över nivå"** som en Developer Product för Robux.
- **Tidtagning** och en global topplista över snabbaste tid (OrderedDataStore).
- **Ljud och effekter** när man tar en checkpoint, plockar mynt eller dör.
- **Fler sektionstyper** i `CourseBuilder.luau`, till exempel väggstudsar,
  transportband eller studsmattor.
