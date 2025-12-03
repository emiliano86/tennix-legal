# Sistema Tornei di Doppio - Guida Completa

## 📋 Panoramica

Sistema completo per gestire tornei di doppio con:
- **16 coppie** (32 giocatori totali)
- **4 gironi da 4 coppie** (fase a gironi)
- **Formato partite**: 2 set a 6 game + tie-break a 10 punti al terzo set
- **Tabellone eliminazione diretta**: Quarti, Semifinali, Finale

## 🗄️ Database Setup

### Step 1: Applicare le Migration

1. Apri Supabase Dashboard: https://app.supabase.com
2. Vai al tuo progetto
3. Clicca su **SQL Editor** nella barra laterale
4. Apri il file `supabase/APPLY_DOUBLES_SYSTEM.sql`
5. Copia tutto il contenuto
6. Incollalo nell'editor SQL di Supabase
7. Clicca **Run**

Il sistema creerà automaticamente:
- 3 nuove tabelle (`tournament_pairs`, `tournament_group_pairs`, `tournament_doubles_matches`)
- Politiche RLS per la sicurezza
- Trigger automatici per calcolo vincitori e statistiche
- Sistema di auto-start quando si registrano 16 coppie
- Generazione automatica semifinali e finale

### Step 2: Creare un Torneo di Doppio

Usa la dashboard Supabase o SQL Editor:

```sql
INSERT INTO tournaments (name, type, max_participants, phase, status, start_date, registration_end, location)
VALUES (
  'Torneo Doppio Estivo 2024',
  'doubles',  -- IMPORTANTE: type deve essere 'doubles'
  16,         -- Numero di coppie (non giocatori individuali)
  'registration',
  'open',
  '2024-07-01',
  '2024-06-25',
  'Tennis Club Roma'
);
```

## 📱 Flutter UI - Pagine Implementate

### 1. DoublesTournamentPage
**File**: `lib/page/doubles_tournament_page.dart`

Pagina principale con 3 tab:
- **Coppie**: Lista delle coppie registrate (X/16)
- **Gironi**: Classifiche dei 4 gironi con statistiche
- **Knockout**: Tabellone eliminazione diretta

**Navigazione automatica**:
- Da `tounaments_page.dart` quando si clicca su un torneo di doppio
- La pagina rileva automaticamente il tipo di torneo

### 2. DoublesTournamentRegisterPage
**File**: `lib/page/doubles_tournament_register_page.dart`

Registrazione coppia:
- Seleziona un partner tra i giocatori disponibili
- Nome coppia opzionale
- Verifica automatica giocatori già registrati
- Bottone di conferma

### 3. DoublesMatchResultPage
**File**: `lib/page/doubles_match_result_page.dart`

Inserimento risultato partita:
- Input punteggi Set 1 e Set 2 (obbligatori)
- Input tie-break Set 3 (solo se 1-1)
- Validazione automatica:
  - Set normale: uno deve vincere 6 game (6-0, 6-1, 6-2, 6-3, 6-4, 7-5, 7-6)
  - Tie-break: uno deve arrivare a 10 punti con 2 di vantaggio
- Calcolo automatico vincitore

## 🔄 Flusso Automatico del Sistema

### 1. Registrazione (Phase: registration)
- Gli utenti formano coppie e si registrano
- Il sistema verifica che ogni giocatore non sia già registrato
- Counter: X/16 coppie

### 2. Auto-Start (Trigger quando raggiunge 16 coppie)
Automaticamente:
1. Phase → `group`
2. Crea 4 gironi da 4 coppie
3. Distribuisce le coppie casualmente
4. Genera 6 partite per girone (round robin)
5. Inizializza statistiche (punti, vittorie, set)

### 3. Fase a Gironi
- Inserimento risultati partite
- Aggiornamento automatico statistiche:
  - Punti (3 per vittoria, 0 per sconfitta)
  - Vittorie/Sconfitte
  - Set vinti/persi
  - Game vinti/persi

### 4. Passaggio Knockout (Trigger quando gironi completati)
Automaticamente quando tutti i match di gruppo sono completati:
1. Phase → `knockout`
2. Seleziona primi 2 di ogni girone (8 coppie)
3. Genera quarti di finale
4. Genera semifinali (4 coppie)
5. Genera finale (2 coppie)

### 5. Completamento Torneo
Quando la finale ha un vincitore:
- Phase → `completed`
- Torneo chiuso

## 📊 Struttura Database

### tournament_pairs
Coppie registrate al torneo
```sql
- id (uuid)
- tournament_id (uuid) → tournaments
- player1_id (uuid) → players
- player2_id (uuid) → players
- pair_name (text, nullable)
- registered_at (timestamp)
```

### tournament_group_pairs
Coppie nei gironi con statistiche
```sql
- id (uuid)
- tournament_id (uuid)
- group_name (text) -- 'Girone A', 'Girone B', etc.
- pair_id (uuid) → tournament_pairs
- points (int) -- Punti totali
- matches_played (int)
- wins (int)
- losses (int)
- sets_won (int)
- sets_lost (int)
- games_won (int)
- games_lost (int)
```

### tournament_doubles_matches
Partite di doppio con punteggi dettagliati
```sql
- id (uuid)
- tournament_id (uuid)
- phase (text) -- 'group' | 'knockout'
- round (text) -- 'group_stage' | 'quarters' | 'semis' | 'final'
- group_name (text, nullable)
- pair1_id (uuid)
- pair2_id (uuid)
- pair1_set1 (int) -- Punteggio coppia 1, set 1
- pair2_set1 (int)
- pair1_set2 (int)
- pair2_set2 (int)
- pair1_set3 (int, nullable) -- Tie-break
- pair2_set3 (int, nullable)
- winner_id (uuid, nullable)
- match_date (timestamp)
```

## 🎾 Regole Punteggio

### Set Normale (Set 1 e 2)
- Vincita a 6 game con almeno 2 di vantaggio
- Punteggi validi: 6-0, 6-1, 6-2, 6-3, 6-4, 7-5, 7-6

### Tie-break (Set 3)
- Si gioca SOLO se il risultato è 1-1 nei set
- Vincita a 10 punti con almeno 2 di vantaggio
- Esempi: 10-0, 10-8, 11-9, 12-10

### Calcolo Vincitore
- Chi vince 2 set vince la partita
- Se 1-1 nei primi due set → tie-break decisivo

## 🧪 Test del Sistema

### 1. Test Registrazione
```sql
-- Verifica coppie registrate
SELECT 
  tp.*,
  p1.name as player1_name,
  p2.name as player2_name
FROM tournament_pairs tp
JOIN players p1 ON tp.player1_id = p1.id
JOIN players p2 ON tp.player2_id = p2.id
WHERE tp.tournament_id = 'YOUR_TOURNAMENT_ID'
ORDER BY tp.registered_at;
```

### 2. Test Gironi
```sql
-- Verifica classifiche gironi
SELECT 
  group_name,
  points,
  wins,
  losses,
  sets_won,
  sets_lost
FROM tournament_group_pairs
WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
ORDER BY group_name, points DESC, sets_won DESC;
```

### 3. Test Match
```sql
-- Verifica partite completate
SELECT 
  phase,
  round,
  pair1_set1, pair2_set1,
  pair1_set2, pair2_set2,
  pair1_set3, pair2_set3,
  winner_id
FROM tournament_doubles_matches
WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
AND winner_id IS NOT NULL
ORDER BY match_date DESC;
```

## 🚀 Come Usare l'App

### Per Organizzatori
1. Crea un torneo con `type='doubles'` nel database
2. Condividi il link/torneo con i giocatori
3. Monitora registrazioni dalla tab "Coppie"
4. Il sistema parte automaticamente a 16 coppie
5. Inserisci risultati dalla tab "Knockout" (tap su partite)

### Per Giocatori
1. Vai alla sezione "Tornei"
2. Tab "Doppio"
3. Clicca su un torneo
4. Bottone "Registra Coppia"
5. Seleziona il partner
6. (Opzionale) Dai un nome alla coppia
7. Conferma registrazione

## 📝 Query Utili

### Trovare i qualificati ai quarti
```sql
SELECT 
  group_name,
  pair_id,
  points,
  sets_won,
  ROW_NUMBER() OVER (PARTITION BY group_name ORDER BY points DESC, sets_won DESC) as position
FROM tournament_group_pairs
WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
HAVING position <= 2;
```

### Classifica finale
```sql
SELECT 
  tp.pair_name,
  p1.name || ' / ' || p2.name as players,
  CASE 
    WHEN winner_final.pair_id IS NOT NULL THEN 'Campioni'
    WHEN loser_final.pair_id IS NOT NULL THEN 'Finalisti'
    WHEN semis.pair_id IS NOT NULL THEN 'Semifinalisti'
    ELSE 'Quarti'
  END as placement
FROM tournament_pairs tp
JOIN players p1 ON tp.player1_id = p1.id
JOIN players p2 ON tp.player2_id = p2.id
LEFT JOIN (SELECT winner_id as pair_id FROM tournament_doubles_matches WHERE round='final') winner_final ON tp.id = winner_final.pair_id
-- ... (continua con altri join)
WHERE tp.tournament_id = 'YOUR_TOURNAMENT_ID';
```

## 🔧 Troubleshooting

### Problema: Torneo non parte a 16 coppie
**Soluzione**: Verifica trigger
```sql
SELECT * FROM pg_trigger 
WHERE tgname = 'auto_start_doubles_tournament_trigger';
```

### Problema: Statistiche non si aggiornano
**Soluzione**: Verifica trigger
```sql
SELECT * FROM pg_trigger 
WHERE tgname IN ('calculate_doubles_winner_trigger', 'update_doubles_group_stats_trigger');
```

### Problema: Knockout non si genera
**Soluzione**: Verifica che tutti i match di gruppo siano completati
```sql
SELECT 
  group_name,
  COUNT(*) as total_matches,
  COUNT(winner_id) as completed_matches
FROM tournament_doubles_matches
WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
AND phase = 'group'
GROUP BY group_name;
```

## 📚 Documentazione Completa

Per maggiori dettagli tecnici, consulta:
- `supabase/migrations/README_DOUBLES_SYSTEM.md` - Documentazione tecnica completa
- `supabase/APPLY_DOUBLES_SYSTEM.sql` - SQL con commenti dettagliati

## ✅ Checklist Implementazione

- [x] Tabelle database create
- [x] Trigger automatici configurati
- [x] RLS policies applicate
- [x] UI registrazione coppia
- [x] UI visualizzazione gironi
- [x] UI inserimento risultati
- [x] UI tabellone knockout
- [x] Validazione punteggi
- [x] Auto-start a 16 coppie
- [x] Auto-generazione knockout
- [x] Calcolo automatico vincitori
- [x] Navigazione integrata

## 🎯 Prossimi Step

1. **Applica le migration**: Esegui `APPLY_DOUBLES_SYSTEM.sql`
2. **Crea un torneo di test**: Usa SQL fornito sopra
3. **Testa la registrazione**: Crea coppie dall'app
4. **Verifica auto-start**: Registra 16 coppie
5. **Inserisci risultati**: Completa partite di girone
6. **Testa knockout**: Verifica generazione automatica

---

**Nota**: Il sistema è completamente automatizzato. Una volta applicate le migration, tutto funziona senza intervento manuale! 🚀
