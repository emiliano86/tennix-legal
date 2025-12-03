#!/bin/bash

# Script per generare il build di release per Play Store

echo "🎾 Tennix - Build Release Script"
echo "=================================="
echo ""

# 1. Verifica che il keystore esista
if [ ! -f "android/keystore/tennix-release-key.jks" ]; then
    echo "❌ Errore: Keystore non trovato!"
    echo ""
    echo "Genera il keystore con:"
    echo "keytool -genkey -v -keystore android/keystore/tennix-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias tennix-key"
    echo ""
    exit 1
fi

# 2. Verifica che key.properties esista
if [ ! -f "android/key.properties" ]; then
    echo "❌ Errore: File key.properties non trovato!"
    echo ""
    echo "Crea il file android/key.properties con:"
    echo "storePassword=<password>"
    echo "keyPassword=<password>"
    echo "keyAlias=tennix-key"
    echo "storeFile=../keystore/tennix-release-key.jks"
    echo ""
    exit 1
fi

echo "✅ Keystore trovato"
echo "✅ key.properties trovato"
echo ""

# 3. Pulisci build precedenti
echo "🧹 Pulizia build precedenti..."
flutter clean
echo ""

# 4. Ottieni le dipendenze
echo "📦 Download dipendenze..."
flutter pub get
echo ""

# 5. Build App Bundle
echo "🔨 Generazione App Bundle..."
flutter build appbundle --release
echo ""

# 6. Verifica che il build sia riuscito
if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    echo "✅ Build completato con successo!"
    echo ""
    echo "📦 App Bundle generato:"
    echo "   build/app/outputs/bundle/release/app-release.aab"
    echo ""
    
    # Mostra dimensione file
    SIZE=$(du -h "build/app/outputs/bundle/release/app-release.aab" | cut -f1)
    echo "📊 Dimensione: $SIZE"
    echo ""
    
    echo "🚀 Prossimi passi:"
    echo "   1. Vai su https://play.google.com/console"
    echo "   2. Seleziona Tennix"
    echo "   3. Vai su 'Release' → 'Produzione'"
    echo "   4. Crea nuova release"
    echo "   5. Carica app-release.aab"
    echo ""
else
    echo "❌ Build fallito!"
    echo "Controlla gli errori sopra"
    exit 1
fi
