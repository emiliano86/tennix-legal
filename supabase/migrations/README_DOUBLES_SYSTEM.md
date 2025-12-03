# Sistema Tornei di Doppio - Istruzioni di Installazione

## 📋 Panoramica
Sistema completo per gestire tornei di doppio con:
- **16 coppie** (32 giocatori totali)
- **4 gironi** da 4 coppie ciascuno
- **Punteggio**: 2 set a 6 game + tie-break a 10 punti al 3° set
- **Fase eliminatoria automatica**: quarti, semifinali, finale

## 🚀 Installazione

### Passo 1: Crea le tabelle base
Esegui il file `20251127000001_doubles_tournaments.sql` nel SQL Editor di Supabase.

Questo creerà:
- `tournament_pairs` - Tabella per le coppie
- `tournament_group_pairs` - Coppie assegnate ai gironi
- `tournament_doubles_matches` - Partite di doppio con punteggio dettagliato

### Passo 2: Attiva il sistema automatico
Esegui il file `20251127000002_doubles_auto_start.sql` nel SQL Editor di Supabase.

Questo creerà:
- Trigger automatico che avvia il torneo quando ci sono 16 coppie
- Funzione per completare i gironi e avviare l'eliminazione diretta
- Trigger per generare automaticamente semifinali e finale

## 📊 Come Funziona

### Registrazione Coppie
```sql
-- Esempio: registra una coppia per un torneo
INSERT INTO tournament_pairs (tournament_id, player1_id, player2_id, pair_name)
VALUES (
  'uuid-del-torneo',
  'uuid-giocatore-1',
  'uuid-giocatore-2',
  'Coppia A' -- opzionale
);
```

Quando vengono registrate 16 coppie:
1. ✅ Il torneo passa automaticamente a `in_progress`
2. ✅ Vengono creati 4 gironi (A, B, C, D)
3. ✅ Le coppie vengono mescolate casualmente e distribuite (4 per girone)
4. ✅ Vengono create 24 partite di girone (6 per girone - round robin)

### Formato Punteggio
Ogni partita ha questo formato:
```sql
set1_pair1_score: 6  -- Coppia 1 vince il primo set 6-4
set1_pair2_score: 4

set2_pair1_score: 4  -- Coppia 2 vince il secondo set 6-4
set2_pair2_score: 6

set3_pair1_score: 10 -- Coppia 1 vince il tie-break 10-7
set3_pair2_score: 7
```

### Inserimento Risultato
```sql
-- Esempio: inserisci il risultato di una partita
UPDATE tournament_doubles_matches
SET 
  set1_pair1_score = 6,
  set1_pair2_score = 4,
  set2_pair1_score = 4,
  set2_pair2_score = 6,
  set3_pair1_score = 10,
  set3_pair2_score = 7
WHERE id = 'uuid-della-partita';

-- Il trigger calcolerà automaticamente:
-- - Chi ha vinto (chi vince 2 set)
-- - Aggiornerà le statistiche del girone
-- - Cambierà lo status a 'completed'
```

### Classifiche Girone
Le coppie vengono ordinate per:
1. **Punti** (10 punti per vittoria)
2. **Partite vinte**
3. **Set vinti**
4. **Game vinti**

Le prime 2 coppie di ogni girone si qualificano per i quarti.

### Fase Eliminatoria
Quando tutte le partite di girone sono completate:

**Quarti di finale** (accoppiamenti fissi):
- Q1: 1° Girone A vs 2° Girone B
- Q2: 1° Girone B vs 2° Girone A
- Q3: 1° Girone C vs 2° Girone D
- Q4: 1° Girone D vs 2° Girone C

**Semifinali** (generate automaticamente):
- SF1: Vincitore Q1 vs Vincitore Q2
- SF2: Vincitore Q3 vs Vincitore Q4

**Finale** (generata automaticamente):
- Vincitore SF1 vs Vincitore SF2

## 🔍 Query Utili

### Visualizza coppie di un torneo
```sql
SELECT 
  tp.id,
  tp.pair_name,
  p1.name as player1_name,
  p2.name as player2_name
FROM tournament_pairs tp
JOIN players p1 ON tp.player1_id = p1.id
JOIN players p2 ON tp.player2_id = p2.id
WHERE tp.tournament_id = 'uuid-del-torneo'
ORDER BY tp.created_at;
```

### Visualizza classifica girone
```sql
SELECT 
  tgp.points,
  tgp.matches_won,
  tgp.matches_lost,
  tgp.sets_won,
  tgp.sets_lost,
  tgp.games_won,
  tgp.games_lost,
  tp.pair_name,
  p1.name as player1,
  p2.name as player2
FROM tournament_group_pairs tgp
JOIN tournament_pairs tp ON tgp.pair_id = tp.id
JOIN players p1 ON tp.player1_id = p1.id
JOIN players p2 ON tp.player2_id = p2.id
JOIN tournament_groups tg ON tgp.group_id = tg.id
WHERE tg.tournament_id = 'uuid-del-torneo'
  AND tg.group_name = 'Girone A'
ORDER BY tgp.points DESC, tgp.matches_won DESC, tgp.sets_won DESC;
```

### Visualizza partite di un girone
```sql
SELECT 
  tdm.id,
  tp1.pair_name as coppia1,
  tp2.pair_name as coppia2,
  tdm.set1_pair1_score || '-' || tdm.set1_pair2_score as set1,
  tdm.set2_pair1_score || '-' || tdm.set2_pair2_score as set2,
  COALESCE(tdm.set3_pair1_score || '-' || tdm.set3_pair2_score, '-') as set3,
  tdm.status
FROM tournament_doubles_matches tdm
JOIN tournament_pairs tp1 ON tdm.pair1_id = tp1.id
JOIN tournament_pairs tp2 ON tdm.pair2_id = tp2.id
JOIN tournament_groups tg ON tdm.group_id = tg.id
WHERE tg.tournament_id = 'uuid-del-torneo'
  AND tg.group_name = 'Girone A'
ORDER BY tdm.created_at;
```

### Visualizza tabellone eliminazione diretta
```sql
SELECT 
  tdm.round,
  tp1.pair_name as coppia1,
  tp2.pair_name as coppia2,
  tdm.set1_pair1_score || '-' || tdm.set1_pair2_score as set1,
  tdm.set2_pair1_score || '-' || tdm.set2_pair2_score as set2,
  COALESCE(tdm.set3_pair1_score || '-' || tdm.set3_pair2_score, '-') as set3,
  tpw.pair_name as vincitore,
  tdm.status
FROM tournament_doubles_matches tdm
JOIN tournament_pairs tp1 ON tdm.pair1_id = tp1.id
JOIN tournament_pairs tp2 ON tdm.pair2_id = tp2.id
LEFT JOIN tournament_pairs tpw ON tdm.winner_pair_id = tpw.id
WHERE tdm.tournament_id = 'uuid-del-torneo'
  AND tdm.phase = 'knockout'
ORDER BY 
  CASE tdm.round
    WHEN 'quarter_final' THEN 1
    WHEN 'semi_final' THEN 2
    WHEN 'final' THEN 3
  END,
  tdm.created_at;
```

## 🧪 Test del Sistema

### Test 1: Avvio Automatico
```sql
-- 1. Crea un torneo di doppio
INSERT INTO tournaments (name, type, max_players, status)
VALUES ('Torneo Doppio Test', 'doppio', 32, 'open')
RETURNING id;

-- 2. Registra 16 coppie (usa l'ID del torneo)
-- Ripeti 16 volte con diversi giocatori
INSERT INTO tournament_pairs (tournament_id, player1_id, player2_id)
VALUES ('uuid-del-torneo', 'uuid-giocatore-1', 'uuid-giocatore-2');

-- 3. Verifica che i gironi siano stati creati
SELECT * FROM tournament_groups WHERE tournament_id = 'uuid-del-torneo';

-- 4. Verifica le partite create
SELECT COUNT(*) FROM tournament_doubles_matches 
WHERE tournament_id = 'uuid-del-torneo' AND phase = 'group';
-- Dovrebbe restituire 24
```

### Test 2: Completamento Fase Gironi
```sql
-- Completa tutte le partite di girone (con punteggi casuali)
SELECT complete_doubles_groups_and_start_knockout();

-- Verifica che i quarti siano stati creati
SELECT COUNT(*) FROM tournament_doubles_matches 
WHERE tournament_id = 'uuid-del-torneo' 
  AND phase = 'knockout' 
  AND round = 'quarter_final';
-- Dovrebbe restituire 4
```

## 🎨 UI Flutter - Widget Necessari

Dovrai creare widget Flutter per:

1. **Pagina Registrazione Coppia**
   - Selezione di 2 giocatori
   - Nome coppia (opzionale)
   - Bottone "Iscriviti"

2. **Pagina Gironi Doppio**
   - Elenco gironi (A, B, C, D)
   - Classifica per ogni girone
   - Partite del girone con punteggio

3. **Pagina Inserimento Risultato Doppio**
   - Input per Set 1: Game Coppia 1 / Game Coppia 2
   - Input per Set 2: Game Coppia 1 / Game Coppia 2
   - Input per Set 3 (tie-break): Punti Coppia 1 / Punti Coppia 2
   - Bottone "Salva Risultato"

4. **Pagina Tabellone Doppio**
   - Visualizzazione quarti, semifinali, finale
   - Nome coppie e risultati

## 📝 Note Importanti

- **Tie-break al 3° set**: Si gioca solo se le coppie sono 1-1 nei set. Va a 10 punti.
- **Regole punteggio set**: 6 game per vincere (con almeno 2 di scarto). 7-5 e 7-6 sono validi.
- **Statistiche automatiche**: Il sistema calcola automaticamente punti, set vinti, game vinti per ogni coppia.
- **Eliminazione diretta automatica**: Semifinali e finale vengono create automaticamente quando le partite precedenti sono completate.

## ✅ Checklist Implementazione

- [x] Tabelle database create
- [x] Trigger automatici configurati
- [x] Sistema di punteggio implementato
- [x] Logica gironi completata
- [x] Fase eliminatoria automatica
- [ ] UI Flutter per registrazione coppie
- [ ] UI Flutter per visualizzazione gironi
- [ ] UI Flutter per inserimento risultati
- [ ] UI Flutter per tabellone eliminatoria

## 🆘 Troubleshooting

### Le coppie non si registrano
Verifica che:
- Il torneo sia di tipo "doppio" o "double"
- Non ci siano già 16 coppie registrate
- I giocatori non siano già in un'altra coppia dello stesso torneo

### I gironi non partono automaticamente
Verifica che:
- Ci siano esattamente 16 coppie registrate
- Il trigger `trigger_auto_start_doubles` sia attivo
- Il torneo non abbia già i gironi creati

### Le semifinali non si generano
Verifica che:
- Tutti e 4 i quarti siano completati (status = 'completed')
- Ogni partita abbia un `winner_pair_id`
- Il trigger `trigger_generate_doubles_semifinals` sia attivo
