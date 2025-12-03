# 📱 Screenshot da Preparare per Play Store

## Telefoni (obbligatorio - min 2 screenshot)
**Dimensione:** 1080x1920px o 1080x2400px

### Screenshot suggeriti:
1. **Schermata Login/Home** - Mostra come accedere e la home page
2. **Lista Tornei** - Visualizzazione tornei disponibili
3. **Dettaglio Torneo** - Gironi e partite di un torneo
4. **Profilo Giocatore** - Statistiche e informazioni personali
5. **Classifica** - Classifica generale giocatori
6. **Match Request** - Richiesta di match tra giocatori
7. **Registrazione Doppio** - Selezione partner per torneo doppio
8. **Risultato Match** - Inserimento punteggio

## Tablet 7" (opzionale)
**Dimensione:** 1024x600px
Gli stessi screenshot ma in formato landscape

## Tablet 10" (opzionale)
**Dimensione:** 1280x800px
Gli stessi screenshot ma in formato landscape

## Come Generare gli Screenshot

### Metodo 1: Emulatore Android Studio
```bash
# Avvia emulatore
flutter emulators --launch <emulator_id>

# Run app
flutter run

# Fai screenshot premendo il pulsante camera nell'emulatore
```

### Metodo 2: Dispositivo Reale
```bash
# Collega il dispositivo
flutter run

# Usa gli screenshot direttamente dal dispositivo
# Android: Power + Volume Giù
```

### Metodo 3: Screenshot Automatici con Fastlane (avanzato)
```bash
# Installa fastlane
gem install fastlane

# Setup screenshots
fastlane snapshot
```

## Post-Produzione Screenshot

### Tool consigliati:
- **Figma** (gratis) - per aggiungere frame dispositivo
- **Canva** (gratis) - per aggiungere testo/decorazioni
- **Screenshot Frames** - per mockup professionali

### Best Practices:
1. ✅ Usa contenuti realistici (nomi, dati, foto)
2. ✅ Mostra funzionalità chiave
3. ✅ Mantieni UI pulita e leggibile
4. ✅ Usa stessa lingua per tutti gli screenshot
5. ✅ Aggiungi brevi descrizioni (opzionale)
6. ❌ Non includere informazioni personali reali
7. ❌ Non mostrare errori o bug

## Feature Graphic (obbligatorio)
**Dimensione:** 1024x500px

### Contenuto suggerito:
- Logo Tennix al centro
- Slogan: "Organizza Tornei, Trova Avversari, Scala la Classifica"
- Colori brand: Verde neon (#00E676) e Nero
- Immagini: Racchette da tennis, pallina, campo

### Tool per creare:
- **Canva** - template "Google Play Feature Graphic"
- **Figma** - design custom
- **Adobe Express** - template pronti

## Icona App (obbligatorio)
**Dimensione:** 512x512px PNG con trasparenza

Già presente in: `assets/images/app_icon.png`

Verifica che:
- [ ] Dimensione esatta 512x512px
- [ ] Formato PNG con canale alpha
- [ ] Icona centrata e ben visibile
- [ ] Contrasto adeguato con sfondi chiari e scuri

## Promo Video (opzionale)
**Durata:** 30 secondi - 2 minuti
**Formato:** MP4, MOV, AVI
**Dimensione max:** 100MB

### Contenuto suggerito:
1. Apertura app e login
2. Creazione torneo
3. Richiesta match
4. Visualizzazione classifica
5. Inserimento risultato
6. Call to action: "Scarica Tennix ora!"

## Checklist Screenshot

- [ ] Minimo 2 screenshot telefono (max 8)
- [ ] Screenshot tablet 7" (opzionale)
- [ ] Screenshot tablet 10" (opzionale)
- [ ] Feature Graphic 1024x500
- [ ] Icona 512x512
- [ ] Promo video (opzionale)
- [ ] Tutti in formato corretto
- [ ] Nomi file descrittivi (es: 01_home.png)
- [ ] Nessuna informazione personale sensibile
- [ ] UI in lingua italiana (o multilingua)

## Struttura Cartelle Suggerita

```
screenshots/
├── phone/
│   ├── 01_login_home.png
│   ├── 02_tournaments_list.png
│   ├── 03_tournament_detail.png
│   ├── 04_player_profile.png
│   ├── 05_leaderboard.png
│   ├── 06_match_request.png
│   ├── 07_doubles_registration.png
│   └── 08_match_result.png
├── tablet_7/
│   └── ...
├── tablet_10/
│   └── ...
├── feature_graphic.png (1024x500)
├── icon_512.png (512x512)
└── promo_video.mp4 (opzionale)
```

## Upload su Play Console

1. Vai su Play Console → Tennix → Presenza nello Store
2. Sezione "Screenshot"
3. Seleziona categoria (Telefono, Tablet 7", ecc.)
4. Trascina e rilascia gli screenshot
5. Riordina trascinando
6. Salva

---

**Suggerimento:** Crea prima gli screenshot su un device/emulatore, poi se necessario aggiungi decorazioni con Figma/Canva prima di uploadarli su Play Console.
