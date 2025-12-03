# Fix Torneo - 16 Giocatori

## Problema
Il torneo ha 16 giocatori iscritti ma non parte automaticamente perché la logica richiedeva esattamente 16 giocatori in un controllo successivo.

## Soluzione

### 1. Script Automatico (Per il futuro)
**File:** `20251112000004_auto_start_tournament_at_16.sql`

Questo script crea un **trigger automatico** che:
- Si attiva quando un giocatore si iscrive a un torneo
- Controlla se il torneo ha raggiunto 16 giocatori
- Avvia automaticamente il torneo creando:
  - 4 gironi (A, B, C, D)
  - 4 giocatori per girone (distribuiti casualmente)
  - 24 partite totali (6 partite per girone - round robin)

**Come usarlo:**
1. Vai su Supabase → SQL Editor
2. Copia e incolla il contenuto del file `20251112000004_auto_start_tournament_at_16.sql`
3. Premi "Run"
4. ✅ D'ora in poi, ogni torneo partirà automaticamente quando si iscrive il 16° giocatore

---

### 2. Script Manuale (Per tornei esistenti)
**File:** `20251112000005_manual_start_existing_tournaments.sql`

Questo script **avvia manualmente** tutti i tornei che:
- Sono in stato `open`
- Hanno già 16 giocatori iscritti
- Non hanno ancora gironi creati

**Come usarlo:**
1. Vai su Supabase → SQL Editor
2. Copia e incolla il contenuto del file `20251112000005_manual_start_existing_tournaments.sql`
3. Premi "Run"
4. ✅ Lo script troverà e avvierà automaticamente tutti i tornei con 16 giocatori

**Output dello script:**
```
=== AVVIO MANUALE TORNEI CON 16 GIOCATORI ===

=== Torneo: Nome Torneo (ID: xyz) ===
Partecipanti: 16
✅ Avvio torneo...
📝 Status → in_progress
🔀 Partecipanti mescolati
✅ 4 Gironi creati
✅ Giocatori distribuiti
✅ 24 partite create (6 per girone)
🎾 TORNEO Nome Torneo AVVIATO!

=== PROCESSO COMPLETATO ===
```

---

## Ordine di Esecuzione

### Se hai un torneo che è già bloccato con 16 giocatori:
1. **Prima:** Esegui `20251112000005_manual_start_existing_tournaments.sql` (avvia i tornei bloccati)
2. **Poi:** Esegui `20251112000004_auto_start_tournament_at_16.sql` (previene il problema in futuro)

### Se non hai tornei bloccati:
1. Esegui solo `20251112000004_auto_start_tournament_at_16.sql`

---

## Verifica

Dopo aver eseguito gli script, verifica su Supabase:

```sql
-- Verifica i gironi creati
SELECT 
  tg.group_name,
  COUNT(tgm.player_id) as giocatori_nel_girone
FROM tournament_groups tg
LEFT JOIN tournament_group_members tgm ON tg.id = tgm.group_id
WHERE tg.tournament_id = 'TUO_TOURNAMENT_ID'
GROUP BY tg.id, tg.group_name
ORDER BY tg.group_name;
```

Dovresti vedere:
```
Girone A | 4
Girone B | 4
Girone C | 4
Girone D | 4
```

```sql
-- Verifica le partite create
SELECT 
  tg.group_name,
  COUNT(tm.id) as partite
FROM tournament_groups tg
LEFT JOIN tournament_matches tm ON tg.id = tm.group_id
WHERE tg.tournament_id = 'TUO_TOURNAMENT_ID'
GROUP BY tg.id, tg.group_name
ORDER BY tg.group_name;
```

Dovresti vedere:
```
Girone A | 6
Girone B | 6
Girone C | 6
Girone D | 6
```

---

## Note Tecniche

- **Distribuzione giocatori:** Casuale (RANDOM())
- **Partite per girone:** 6 (ogni giocatore gioca contro gli altri 3 del suo girone)
- **Totale partite fase a gironi:** 24
- **Sistema punti:** 10 punti per vittoria, 0 per sconfitta
- **Qualificazione:** I primi 2 di ogni girone passano alla fase eliminatoria (8 giocatori)

---

## In caso di problemi

Se dopo aver eseguito lo script manuale vedi errori o comportamenti strani:

1. Controlla i log nel terminale di Supabase
2. Verifica che tutti i 16 giocatori siano in stato `active=true`:
```sql
SELECT COUNT(*) 
FROM tournaments_user 
WHERE tournament_id = 'TUO_TOURNAMENT_ID' 
  AND active = true;
```
3. Se servono solo 15 giocatori, aggiungi un giocatore manualmente o modifica il max_participants
