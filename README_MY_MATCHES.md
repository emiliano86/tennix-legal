# Sistema di Punteggio e Partite

## Pagina "Le Mie Partite"

Gli utenti possono ora vedere tutte le loro partite programmate nella nuova tab "Partite" della bottom navigation bar.

### Funzionalità

1. **Visualizzazione Partite**
   - Mostra tutte le partite dell'utente (come player1 o player2)
   - Ordinate per stato: prima le partite da giocare, poi quelle completate
   - Ogni card mostra:
     - Torneo e girone di appartenenza
     - Avversario con avatar
     - Stato: "Da giocare", "Vittoria" o "Sconfitta"
     - Punteggio (se completata)

2. **Inserimento Risultato**
   - Solo per partite non completate
   - Dialog intuitivo con counter per il punteggio
   - Set lungo fino a 9 punti (es: 9-1, 9-4, 9-7)
   - Validazione: il punteggio non può essere pari
   - Ogni vittoria vale **2 punti** nella classifica del girone

3. **Aggiornamento Automatico**
   - Pull to refresh per ricaricare le partite
   - Aggiornamento automatico dopo l'inserimento del risultato
   - Trigger database aggiorna automaticamente:
     - Statistiche del girone
     - Punti dei giocatori
     - Partite vinte/perse

## Regole del Torneo

### Fase Gironi
- 16 giocatori divisi in 4 gironi da 4
- Ogni girone: round robin (tutti contro tutti)
- 6 partite per girone
- Set unico lungo fino a 9 punti

### Sistema Punti
- **Vittoria**: 2 punti
- **Sconfitta**: 0 punti
- La classifica si basa su:
  1. Punti totali
  2. Numero di vittorie (in caso di parità)

### Fase Knockout
- I primi 2 di ogni girone si qualificano (8 giocatori)
- Quarti di finale → Semifinali → Finale
- Accoppiamenti casuali
- Sempre set lungo fino a 9 punti

## Migliorie Implementate

### 1. Controllo Registrazioni
- Impedisce registrazioni oltre il limite di 16 giocatori
- Mostra messaggio informativo con il conteggio
- Torneo non aperto = registrazione bloccata

### 2. Avvio Automatico Torneo
- Parte automaticamente con esattamente 16 giocatori
- Crea esattamente 4 gironi da 4
- Previene creazione di gironi duplicati
- Aggiorna stato torneo a "in_progress"

### 3. Inserimento Risultati
- Gli organizzatori possono inserire risultati dalla pagina gironi
- Gli utenti possono inserire risultati dalla pagina "Le Mie Partite"
- Trigger automatico aggiorna le statistiche

### 4. Fase Knockout Automatica
- Pulsante appare solo quando tutte le partite dei gironi sono completate
- Mostra statistiche di completamento
- Verifica che ci siano esattamente 8 qualificati
- Crea automaticamente i quarti di finale

## Database

### Trigger: update_group_stats_on_match_result

Aggiorna automaticamente le statistiche quando viene completata una partita:
- `matches_played` +1 per entrambi
- `matches_won` +1 per il vincitore
- `matches_lost` +1 per il perdente
- `points` +2 per il vincitore

### Tabelle Coinvolte
- `tournament_matches`: partite programmate
- `tournament_group_members`: membri dei gironi con statistiche
- `tournament_groups`: gironi del torneo
- `tournaments`: informazioni torneo e fase corrente

## File Modificati

1. `/lib/page/my_matches_page.dart` - Nuova pagina per le partite dell'utente
2. `/lib/page/main_page.dart` - Aggiunta tab "Partite"
3. `/lib/page/tounaments_page.dart` - Controlli registrazione e avvio automatico
4. `/lib/page/tournament_groups_page.dart` - Miglioramenti fase knockout
5. `/supabase/migrations/20251107000005_create_match_result_trigger.sql` - Trigger aggiornamento statistiche

## Come Usare

### Per gli Utenti
1. Vai alla tab "Partite" dalla bottom navigation
2. Vedi le tue partite programmate
3. Per le partite da giocare, clicca "Inserisci Risultato"
4. Usa i pulsanti + e - per impostare il punteggio
5. Il vincitore riceverà automaticamente 2 punti nella classifica del girone

### Per gli Organizzatori
1. Crea un torneo con max_participants = 16
2. Quando si registrano 16 giocatori, il torneo parte automaticamente
3. Vengono creati 4 gironi da 4 giocatori
4. Vengono generate 24 partite (6 per girone)
5. Quando tutte le partite dei gironi sono completate, clicca "Avvia Quarti di Finale"
6. I primi 2 di ogni girone passano ai quarti (8 giocatori)

## Prossimi Sviluppi

- [ ] Notifiche push per nuove partite
- [ ] Chat tra giocatori per accordarsi
- [ ] Calendario partite con data e ora
- [ ] Statistiche avanzate per giocatore
- [ ] Export risultati in PDF
