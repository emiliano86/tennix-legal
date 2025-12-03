# Script di Test - Sistema Tornei di Doppio

## 🎬 Demo Flow

### 1. SETUP DATABASE (5 minuti)

```sql
-- 1. Applica APPLY_DOUBLES_SYSTEM.sql in Supabase SQL Editor

-- 2. Crea un torneo di test
INSERT INTO tournaments (
  name, 
  type, 
  max_participants, 
  phase, 
  status, 
  start_date, 
  registration_end, 
  location,
  regulation
)
VALUES (
  'Torneo Doppio Test 2024',
  'doubles',
  16,
  'registration',
  'open',
  CURRENT_DATE + INTERVAL '7 days',
  CURRENT_DATE + INTERVAL '3 days',
  'Tennis Club Test',
  'Torneo di doppio formato: 2 set a 6 game + tie-break a 10 punti al terzo set. 4 gironi da 4 coppie, poi eliminazione diretta.'
)
RETURNING id;

-- Salva l'ID del torneo per i prossimi step
```

### 2. TEST REGISTRAZIONE COPPIE (10 minuti)

**Nell'App Flutter:**

1. Apri l'app
2. Vai su "Tornei" → Tab "Doppio"
3. Clicca sul torneo "Torneo Doppio Test 2024"
4. Clicca "Registra Coppia"
5. Seleziona un partner
6. (Opzionale) Scrivi un nome coppia: "I Campioni"
7. Clicca "Conferma"
8. Verifica: Ritorna alla pagina torneo
9. Tab "Coppie" deve mostrare "1/16 Coppie"

**Ripeti 15 volte con utenti/account diversi per raggiungere 16 coppie**

**Shortcut per Test Rapido (SQL):**
```sql
-- Inserisci 16 coppie manualmente per test veloce
DO $$
DECLARE
  tournament_uuid UUID := 'YOUR_TOURNAMENT_ID'; -- Sostituisci con l'ID del torneo
  player_ids UUID[] := ARRAY(SELECT id FROM players LIMIT 32);
BEGIN
  FOR i IN 1..16 LOOP
    INSERT INTO tournament_pairs (tournament_id, player1_id, player2_id, pair_name)
    VALUES (
      tournament_uuid,
      player_ids[i*2-1],
      player_ids[i*2],
      'Coppia Test ' || i
    );
  END LOOP;
END $$;

-- Verifica creazione automatica gironi
SELECT 
  t.phase,
  COUNT(DISTINCT tgp.group_name) as num_groups,
  COUNT(tgp.id) as total_pairs_in_groups
FROM tournaments t
LEFT JOIN tournament_group_pairs tgp ON t.id = tgp.tournament_id
WHERE t.id = 'YOUR_TOURNAMENT_ID'
GROUP BY t.phase;

-- Dovrebbe mostrare: phase='group', num_groups=4, total_pairs_in_groups=16
```

### 3. TEST FASE GIRONI (15 minuti)

**Verifica Auto-Start:**
```sql
-- Controlla che il torneo sia partito automaticamente
SELECT 
  id,
  name,
  phase,  -- Deve essere 'group'
  status  -- Deve essere 'in_progress' o 'open'
FROM tournaments
WHERE id = 'YOUR_TOURNAMENT_ID';

-- Controlla i gironi creati
SELECT 
  group_name,
  COUNT(*) as num_pairs
FROM tournament_group_pairs
WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
GROUP BY group_name
ORDER BY group_name;

-- Dovrebbe mostrare:
-- Girone A: 4 coppie
-- Girone B: 4 coppie
-- Girone C: 4 coppie
-- Girone D: 4 coppie

-- Controlla i match generati
SELECT 
  group_name,
  COUNT(*) as num_matches
FROM tournament_doubles_matches
WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
AND phase = 'group'
GROUP BY group_name;

-- Dovrebbe mostrare: 6 match per girone (24 totali)
```

**Nell'App Flutter:**
1. Riapri il torneo
2. Tab "Gironi" deve mostrare 4 gironi
3. Ogni girone ha 4 coppie con statistiche a 0

### 4. TEST INSERIMENTO RISULTATI (20 minuti)

**Nell'App Flutter:**

1. Tab "Knockout" (anche se fase=group, i match si vedono qui)
2. Trova le partite del "Girone A"
3. Tap su una partita
4. Inserisci punteggi:
   - Set 1: `6` - `2`
   - Set 2: `6` - `4`
   - Lascia Set 3 vuoto (vittoria 2-0)
5. Clicca "Conferma Risultato"
6. Verifica: Ritorna al tabellone
7. La partita mostra il punteggio e il vincitore

**Ripeti per tutte le 24 partite di girone**

**Shortcut per Test Rapido (SQL):**
```sql
-- Completa automaticamente tutti i match di gruppo con punteggi casuali
DO $$
DECLARE
  match RECORD;
  p1_set1 INT;
  p2_set1 INT;
  p1_set2 INT;
  p2_set2 INT;
BEGIN
  FOR match IN 
    SELECT id FROM tournament_doubles_matches 
    WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
    AND phase = 'group'
    AND winner_id IS NULL
  LOOP
    -- Genera punteggi casuali ma validi
    p1_set1 := (RANDOM() * 2 + 5)::INT; -- 5-7
    p2_set1 := CASE WHEN p1_set1 = 6 THEN (RANDOM() * 4)::INT ELSE (RANDOM() * 2 + 5)::INT END;
    
    p1_set2 := (RANDOM() * 2 + 5)::INT;
    p2_set2 := CASE WHEN p1_set2 = 6 THEN (RANDOM() * 4)::INT ELSE (RANDOM() * 2 + 5)::INT END;
    
    -- Aggiorna il match (trigger calcolerà il vincitore)
    UPDATE tournament_doubles_matches
    SET 
      pair1_set1 = p1_set1,
      pair2_set1 = p2_set1,
      pair1_set2 = p1_set2,
      pair2_set2 = p2_set2,
      match_date = NOW()
    WHERE id = match.id;
  END LOOP;
END $$;

-- Verifica vincitori calcolati
SELECT 
  group_name,
  COUNT(*) as total_matches,
  COUNT(winner_id) as completed_matches
FROM tournament_doubles_matches
WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
AND phase = 'group'
GROUP BY group_name;

-- Tutte le partite devono avere winner_id
```

**Verifica Statistiche Aggiornate:**
```sql
-- Controlla classifiche gironi
SELECT 
  group_name,
  pair_id,
  points,
  wins,
  losses,
  sets_won,
  sets_lost,
  games_won,
  games_lost
FROM tournament_group_pairs
WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
ORDER BY group_name, points DESC, sets_won DESC;
```

**Nell'App Flutter:**
1. Ricarica (pull down)
2. Tab "Gironi"
3. Verifica che le statistiche siano aggiornate
4. Primi 2 di ogni girone evidenziati

### 5. TEST FASE KNOCKOUT (25 minuti)

**Verifica Auto-Generazione:**
```sql
-- Controlla che i quarti siano stati creati
SELECT 
  t.phase,  -- Deve essere 'knockout'
  COUNT(*) FILTER (WHERE tdm.round = 'quarters') as quarti,
  COUNT(*) FILTER (WHERE tdm.round = 'semis') as semifinali,
  COUNT(*) FILTER (WHERE tdm.round = 'final') as finali
FROM tournaments t
LEFT JOIN tournament_doubles_matches tdm ON t.id = tdm.tournament_id
WHERE t.id = 'YOUR_TOURNAMENT_ID'
GROUP BY t.phase;

-- Dovrebbe mostrare: phase='knockout', quarti=4, semifinali=2, finali=1
```

**Nell'App Flutter:**
1. Riapri il torneo
2. Tab "Knockout"
3. Sezione "Quarti di Finale" con 4 match
4. Sezione "Semifinali" con 2 match (non completati)
5. Sezione "Finale" con 1 match (non completato)

**Test Inserimento Risultati Quarti:**
```sql
-- Completa i quarti di finale
UPDATE tournament_doubles_matches
SET 
  pair1_set1 = 6, pair2_set1 = 3,
  pair1_set2 = 6, pair2_set2 = 4,
  match_date = NOW()
WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
AND round = 'quarters'
AND winner_id IS NULL;

-- Verifica vincitori
SELECT 
  round,
  pair1_id,
  pair2_id,
  winner_id
FROM tournament_doubles_matches
WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
AND round = 'quarters';
```

**Test Inserimento Risultati Semifinali:**
```sql
-- Completa le semifinali
UPDATE tournament_doubles_matches
SET 
  pair1_set1 = 6, pair2_set1 = 4,
  pair1_set2 = 7, pair2_set2 = 5,
  match_date = NOW()
WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
AND round = 'semis'
AND winner_id IS NULL;
```

**Test Finale:**
```sql
-- Completa la finale (con tie-break!)
UPDATE tournament_doubles_matches
SET 
  pair1_set1 = 6, pair2_set1 = 4,
  pair1_set2 = 4, pair2_set2 = 6,
  pair1_set3 = 10, pair2_set3 = 7,  -- Tie-break
  match_date = NOW()
WHERE tournament_id = 'YOUR_TOURNAMENT_ID'
AND round = 'final'
AND winner_id IS NULL;

-- Verifica campioni
SELECT 
  tp.pair_name,
  p1.name || ' / ' || p2.name as players,
  'CAMPIONI' as title
FROM tournament_doubles_matches tdm
JOIN tournament_pairs tp ON tdm.winner_id = tp.id
JOIN players p1 ON tp.player1_id = p1.id
JOIN players p2 ON tp.player2_id = p2.id
WHERE tdm.tournament_id = 'YOUR_TOURNAMENT_ID'
AND tdm.round = 'final';
```

### 6. VERIFICA FINALE (5 minuti)

**Nell'App Flutter:**

1. Riapri il torneo
2. **Tab "Coppie"**: 
   - Mostra "16/16 Coppie"
   - Status: "Torneo completato"
3. **Tab "Gironi"**: 
   - 4 gironi con classifiche finali
   - Primi 2 evidenziati
4. **Tab "Knockout"**:
   - Quarti completati
   - Semifinali completate
   - Finale completata con CAMPIONI

**Verifica Database:**
```sql
-- Report completo del torneo
SELECT 
  t.name,
  t.phase,
  t.status,
  COUNT(DISTINCT tp.id) as total_pairs,
  COUNT(DISTINCT tdm.id) as total_matches,
  COUNT(DISTINCT tdm.id) FILTER (WHERE tdm.winner_id IS NOT NULL) as completed_matches
FROM tournaments t
LEFT JOIN tournament_pairs tp ON t.id = tp.tournament_id
LEFT JOIN tournament_doubles_matches tdm ON t.id = tdm.tournament_id
WHERE t.id = 'YOUR_TOURNAMENT_ID'
GROUP BY t.name, t.phase, t.status;
```

## ✅ Checklist Test Completato

- [ ] Database migration applicata
- [ ] Torneo creato con type='doubles'
- [ ] 16 coppie registrate
- [ ] Auto-start attivato (phase='group')
- [ ] 4 gironi creati con 4 coppie ciascuno
- [ ] 24 match di gruppo generati (6 per girone)
- [ ] Tutti i match di gruppo completati
- [ ] Statistiche gironi aggiornate correttamente
- [ ] Auto-generazione knockout (phase='knockout')
- [ ] 4 quarti di finale generati
- [ ] Quarti completati
- [ ] 2 semifinali generate automaticamente
- [ ] Semifinali completate
- [ ] 1 finale generata automaticamente
- [ ] Finale completata con tie-break
- [ ] Campioni determinati
- [ ] UI mostra tutto correttamente

## 🎯 Test Specifici da Eseguire

### Test 1: Validazione Punteggi
Prova a inserire punteggi non validi:
- Set 1: `6` - `6` → Deve dare errore
- Set 2: `5` - `4` → Deve dare errore
- Tie-break: `9` - `8` → Deve dare errore
- Tie-break: `10` - `8` → Deve funzionare ✅

### Test 2: Registro Giocatore Già Registrato
1. Registra una coppia (Giocatore A + Giocatore B)
2. Prova a registrare un'altra coppia con Giocatore A
3. Deve dare errore: "Giocatore già registrato"

### Test 3: Auto-Start con Meno di 16 Coppie
1. Registra solo 15 coppie
2. Verifica: phase rimane 'registration'
3. Registra la 16ª coppia
4. Verifica: phase diventa 'group' automaticamente

### Test 4: Qualificazione ai Quarti
1. Completa tutti i match di gruppo
2. Verifica SQL:
```sql
-- I primi 2 di ogni girone devono essere nei quarti
SELECT 
  tgp.group_name,
  tgp.pair_id,
  tgp.points,
  CASE WHEN tdm.pair1_id = tgp.pair_id OR tdm.pair2_id = tgp.pair_id 
    THEN 'Qualificato' 
    ELSE 'Eliminato' 
  END as status
FROM tournament_group_pairs tgp
LEFT JOIN tournament_doubles_matches tdm ON (tdm.pair1_id = tgp.pair_id OR tdm.pair2_id = tgp.pair_id)
  AND tdm.round = 'quarters'
WHERE tgp.tournament_id = 'YOUR_TOURNAMENT_ID'
ORDER BY tgp.group_name, tgp.points DESC;
```

## 📊 Report Finale

Al termine del test, genera un report:

```sql
-- Report Completo Torneo
WITH tournament_summary AS (
  SELECT 
    t.name,
    COUNT(DISTINCT tp.id) as pairs,
    COUNT(DISTINCT tdm.id) as matches,
    COUNT(DISTINCT tdm.id) FILTER (WHERE tdm.winner_id IS NOT NULL) as completed
  FROM tournaments t
  LEFT JOIN tournament_pairs tp ON t.id = tp.tournament_id
  LEFT JOIN tournament_doubles_matches tdm ON t.id = tdm.tournament_id
  WHERE t.id = 'YOUR_TOURNAMENT_ID'
  GROUP BY t.name
),
champion AS (
  SELECT 
    tp.pair_name,
    p1.name || ' / ' || p2.name as players
  FROM tournament_doubles_matches tdm
  JOIN tournament_pairs tp ON tdm.winner_id = tp.id
  JOIN players p1 ON tp.player1_id = p1.id
  JOIN players p2 ON tp.player2_id = p2.id
  WHERE tdm.tournament_id = 'YOUR_TOURNAMENT_ID'
  AND tdm.round = 'final'
)
SELECT 
  ts.*,
  c.pair_name as champion_name,
  c.players as champion_players
FROM tournament_summary ts
CROSS JOIN champion c;
```

---

**Tempo totale stimato**: 80 minuti
**Difficoltà**: Media
**Prerequisiti**: Database Supabase configurato, Flutter app funzionante

🎉 **Buon test!**
