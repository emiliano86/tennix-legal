# 🎾 Tennix - Guida Distribuzione Play Store

## 📋 Checklist Pre-Pubblicazione

### 1️⃣ Generare il Keystore di Firma

```bash
cd android/app
keytool -genkey -v -keystore tennix-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias tennix-key
```

**Informazioni da inserire:**
- Password keystore: [Scegli una password sicura]
- Nome e Cognome: Emiliano
- Unità Organizzativa: Tennix
- Organizzazione: Tennix
- Città: [La tua città]
- Provincia: [La tua provincia]
- Codice Paese: IT

**⚠️ IMPORTANTE:** Salva la password in modo sicuro! Non potrai più aggiornare l'app senza questo file.

### 2️⃣ Configurare le Variabili d'Ambiente

Crea il file `android/key.properties`:

```properties
storePassword=[LA_TUA_PASSWORD_KEYSTORE]
keyPassword=[LA_TUA_PASSWORD_KEY]
keyAlias=tennix-key
storeFile=../keystore/tennix-release-key.jks
```

**Sposta il keystore:**
```bash
mkdir -p android/keystore
mv android/app/tennix-release-key.jks android/keystore/
```

### 3️⃣ Aggiornare build.gradle.kts

Decommenta nel file `android/app/build.gradle.kts` le righe:

```kotlin
// Cerca questa sezione e decommentala:
signingConfigs {
    release {
        storeFile = file("../keystore/tennix-release-key.jks")
        storePassword = System.getenv("KEYSTORE_PASSWORD") ?: project.property("storePassword").toString()
        keyAlias = System.getenv("KEY_ALIAS") ?: project.property("keyAlias").toString()
        keyPassword = System.getenv("KEY_PASSWORD") ?: project.property("keyPassword").toString()
    }
}
```

### 4️⃣ Build della Release

```bash
# Pulisci build precedenti
flutter clean

# Build App Bundle (formato richiesto da Play Store)
flutter build appbundle --release

# Il file sarà in: build/app/outputs/bundle/release/app-release.aab
```

### 5️⃣ Preparare Materiali Play Store

#### Screenshot richiesti (minimo 2 per categoria):
- **Telefono:** 1080x1920px o 1080x2400px
- **Tablet 7":** 1024x600px
- **Tablet 10":** 1280x800px

#### Icona app:
- **512x512px** formato PNG con trasparenza
- Già configurata in `assets/images/app_icon.png`

#### Feature Graphic:
- **1024x500px** formato PNG/JPG
- Banner principale nella scheda Play Store

#### Descrizione:

**Breve (80 caratteri max):**
```
Organizza tornei di tennis, trova avversari e traccia le tue partite!
```

**Completa:**
```
🎾 Tennix - L'app definitiva per gli appassionati di tennis!

Organizza tornei singoli e di doppio, trova avversari nella tua zona, traccia le tue partite e scala la classifica!

✨ CARATTERISTICHE PRINCIPALI:

🏆 TORNEI
• Crea tornei singoli e di doppio
• Sistema gironi + knockout automatico
• Supporto per 16 coppie nei tornei di doppio
• Gironi da 4 coppie con top 2 che passano
• Tracciamento punteggi dettagliato

👥 MATCH & SFIDE
• Invia richieste di match ai giocatori
• Notifiche push per nuove sfide
• Registra risultati delle partite
• Storico completo delle tue partite

📊 CLASSIFICA
• Classifica generale giocatori
• Statistiche personali dettagliate
• Vittorie, sconfitte, set e game
• Tracciamento progressi nel tempo

👤 PROFILO
• Crea e personalizza il tuo profilo
• Foto profilo e informazioni personali
• Visualizza statistiche personali
• Storico tornei e partite

🔔 NOTIFICHE
• Notifiche per nuove sfide
• Avvisi accettazione match
• Aggiornamenti tornei
• Risultati partite

Unisciti alla community Tennix e porta il tuo gioco al livello successivo! 🚀
```

#### Categoria Play Store:
- **Sport**

#### Classificazione contenuti:
- **PEGI 3** (Per tutti)
- Nessuna violenza, linguaggio offensivo o contenuti per adulti

#### Privacy Policy:
È richiesta una Privacy Policy. Vedi `PRIVACY_POLICY.md`

### 6️⃣ Compilare il Modulo Play Console

1. Accedi a [Google Play Console](https://play.google.com/console)
2. Crea nuova applicazione "Tennix"
3. Carica l'App Bundle (`.aab`)
4. Compila tutte le sezioni richieste:
   - Scheda del Play Store
   - Classificazione contenuti
   - App pricing (Gratuita)
   - Paesi di distribuzione
   - Privacy policy
   - Autorizzazioni
   - Screenshot e video

### 7️⃣ Testing Interno/Chiuso

Prima della pubblicazione pubblica:

1. **Testing Interno:** Testa con 100 utenti max
2. **Testing Chiuso:** Testa con gruppo selezionato
3. **Testing Aperto:** Beta pubblica (opzionale)

```bash
# Per testing, genera build di test:
flutter build appbundle --release --build-name=1.0.0-beta.1 --build-number=2
```

### 8️⃣ Sicurezza Firebase

**⚠️ IMPORTANTE:** Prima della pubblicazione:

1. Rimuovi `chiave-fcm.json` dal repository
2. Aggiungi al `.gitignore`:
   ```
   chiave-fcm.json
   android/keystore/
   android/key.properties
   ```

3. Configura le credenziali Firebase in modo sicuro
4. Abilita App Check in Firebase Console

### 9️⃣ Aggiornamenti Futuri

Per pubblicare aggiornamenti:

1. Aggiorna `version` in `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # 1.0.1 = versionName, 2 = versionCode
   ```

2. Build nuova versione:
   ```bash
   flutter build appbundle --release
   ```

3. Carica su Play Console → Nuova release

### 🔟 Comandi Utili

```bash
# Verifica firma dell'app
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab

# Genera SHA-1 per Google Sign-In
keytool -list -v -keystore android/keystore/tennix-release-key.jks -alias tennix-key

# Test build release su dispositivo
flutter install --release

# Analizza dimensione bundle
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab --output=app.apks --mode=universal
```

## ✅ Checklist Finale

- [ ] Keystore generato e salvato in modo sicuro
- [ ] `key.properties` configurato
- [ ] Build release generata senza errori
- [ ] App testata in modalità release
- [ ] Screenshot preparati (tutti i formati)
- [ ] Icona 512x512 pronta
- [ ] Feature Graphic 1024x500 pronta
- [ ] Descrizione scritta
- [ ] Privacy Policy pubblicata
- [ ] File sensibili rimossi dal repository
- [ ] Firebase configurato correttamente
- [ ] SHA-1 aggiunto a Firebase Console
- [ ] App Bundle caricato su Play Console
- [ ] Tutte le sezioni Play Console compilate
- [ ] Testing interno completato

## 📞 Supporto

Per problemi durante la pubblicazione:
- [Play Console Help](https://support.google.com/googleplay/android-developer)
- [Flutter Release Guide](https://docs.flutter.dev/deployment/android)

---

**Buona pubblicazione! 🚀**
