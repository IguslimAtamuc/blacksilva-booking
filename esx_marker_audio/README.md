# esx_marker_audio

Script FiveM pentru ESX care afiseaza un marker si reda un fisier audio MP3 atunci cand un jucator intra in cerc.

## Functionalitati

- **Marker tip 27** de culoare **alba** la coordonatele `382.4492, -1076.2772, 29.4699`
- Cand un jucator **intra in cerc**, porneste automat un **audio MP3**
- Redarea audio se face prin **NUI** (suport complet MP3)
- **Fisier de config** complet pentru a modifica markerul, coordonatele, culorile, audio-ul etc.

## Instalare

1. Copiaza folderul `esx_marker_audio` in directorul `resources/` al serverului tau.
2. Pune fisierul tau **MP3** in `html/audio/` (implicit: `audio.mp3`).
   - Daca numele difera, modifica `Config.Audio.file` in `config.lua`.
3. Adauga in `server.cfg`:
   ```
   ensure esx_marker_audio
   ```
4. Reporneste serverul.

## Configurare (config.lua)

| Optiune | Descriere |
|---|---|
| `Config.DrawDistance` | Distanta de la care se randeaza markerul |
| `Config.Marker.type` | Tipul markerului (implicit 27) |
| `Config.Marker.coords` | Coordonatele markerului |
| `Config.Marker.size` | Dimensiunea markerului (x, y, z) |
| `Config.Marker.color` | Culoarea markerului (RGBA) |
| `Config.TriggerRadius` | Raza cercului care declanseaza audio-ul |
| `Config.Audio.file` | Numele fisierului MP3 |
| `Config.Audio.volume` | Volumul (0.0 - 1.0) |
| `Config.Audio.loop` | Redare in bucla |
| `Config.Audio.stopOnLeave` | Opreste audio-ul la iesirea din cerc |

## Structura

```
esx_marker_audio/
├── fxmanifest.lua
├── config.lua
├── client.lua
├── README.md
└── html/
    ├── index.html
    └── audio/
        └── audio.mp3   <-- pune fisierul tau MP3 aici
```

## Dependinte

- [es_extended](https://github.com/esx-framework/esx_core) (ESX)
