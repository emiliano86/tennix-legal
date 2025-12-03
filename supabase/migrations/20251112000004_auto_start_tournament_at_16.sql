-- Trigger automatico per avviare torneo quando raggiunge 16 giocatori
-- Crea gironi e partite automaticamente

-- Funzione per creare i gironi e le partite
CREATE OR REPLACE FUNCTION auto_start_tournament_with_groups()
RETURNS TRIGGER AS $$
DECLARE
  participant_count INTEGER;
  max_participants INTEGER;
  tournament_status TEXT;
  existing_groups_count INTEGER;
  shuffled_participants UUID[];
  group_id_a UUID;
  group_id_b UUID;
  group_id_c UUID;
  group_id_d UUID;
  group_ids UUID[];
  player_idx INTEGER;
  current_group_idx INTEGER;
  p1_id UUID;
  p2_id UUID;
BEGIN
  RAISE NOTICE '=== TRIGGER: Verifica avvio torneo ===';
  
  -- 1. Ottieni dettagli torneo
  SELECT max_participants, status 
  INTO max_participants, tournament_status
  FROM tournaments 
  WHERE id = NEW.tournament_id;
  
  RAISE NOTICE 'Max partecipanti: %, Status: %', max_participants, tournament_status;
  
  -- Controlla se il torneo è aperto
  IF tournament_status != 'open' THEN
    RAISE NOTICE 'Torneo non aperto (status: %), uscita trigger', tournament_status;
    RETURN NEW;
  END IF;
  
  -- 2. Conta i partecipanti attivi
  SELECT COUNT(*) 
  INTO participant_count
  FROM tournaments_user 
  WHERE tournament_id = NEW.tournament_id 
    AND active = true;
  
  RAISE NOTICE 'Partecipanti attuali: %/%', participant_count, max_participants;
  
  -- 3. Verifica se ha raggiunto esattamente 16 giocatori
  IF participant_count != 16 THEN
    RAISE NOTICE 'Non ancora 16 giocatori (attuale: %), uscita trigger', participant_count;
    RETURN NEW;
  END IF;
  
  -- 4. Verifica se i gironi sono già stati creati
  SELECT COUNT(*) 
  INTO existing_groups_count
  FROM tournament_groups 
  WHERE tournament_id = NEW.tournament_id;
  
  IF existing_groups_count > 0 THEN
    RAISE NOTICE 'Gironi già esistenti (%), uscita trigger', existing_groups_count;
    RETURN NEW;
  END IF;
  
  RAISE NOTICE '✅ AVVIO AUTOMATICO TORNEO!';
  
  -- 5. Aggiorna stato torneo a "in_progress" e marca gironi come creati
  UPDATE tournaments 
  SET status = 'in_progress',
      actual_start_date = NOW(),
      groups_created = true
  WHERE id = NEW.tournament_id;
  
  RAISE NOTICE '📝 Status torneo aggiornato a in_progress, groups_created = true';
  
  -- 6. Ottieni tutti i partecipanti in ordine casuale
  SELECT ARRAY_AGG(user_id ORDER BY RANDOM())
  INTO shuffled_participants
  FROM tournaments_user
  WHERE tournament_id = NEW.tournament_id 
    AND active = true;
  
  RAISE NOTICE '🔀 Partecipanti mescolati';
  
  -- 7. Crea i 4 gironi
  INSERT INTO tournament_groups (tournament_id, group_name)
  VALUES (NEW.tournament_id, 'Girone A')
  RETURNING id INTO group_id_a;
  
  INSERT INTO tournament_groups (tournament_id, group_name)
  VALUES (NEW.tournament_id, 'Girone B')
  RETURNING id INTO group_id_b;
  
  INSERT INTO tournament_groups (tournament_id, group_name)
  VALUES (NEW.tournament_id, 'Girone C')
  RETURNING id INTO group_id_c;
  
  INSERT INTO tournament_groups (tournament_id, group_name)
  VALUES (NEW.tournament_id, 'Girone D')
  RETURNING id INTO group_id_d;
  
  group_ids := ARRAY[group_id_a, group_id_b, group_id_c, group_id_d];
  
  RAISE NOTICE '✅ 4 Gironi creati';
  
  -- 8. Distribuisci i giocatori nei gironi (4 per girone)
  FOR player_idx IN 1..16 LOOP
    current_group_idx := ((player_idx - 1) / 4) + 1; -- 1,2,3,4
    
    INSERT INTO tournament_group_members (group_id, player_id, points, matches_played, matches_won, matches_lost)
    VALUES (
      group_ids[current_group_idx],
      shuffled_participants[player_idx],
      0, 0, 0, 0
    );
  END LOOP;
  
  RAISE NOTICE '✅ Giocatori distribuiti nei gironi';
  
  -- 9. Crea le partite per ogni girone (round robin - tutti contro tutti)
  FOR current_group_idx IN 1..4 LOOP
    -- Ottieni i 4 giocatori del girone
    DECLARE
      group_players UUID[];
    BEGIN
      SELECT ARRAY_AGG(player_id)
      INTO group_players
      FROM tournament_group_members
      WHERE group_id = group_ids[current_group_idx];
      
      -- Crea tutte le combinazioni (6 partite per girone: 4!/2!(4-2)! = 6)
      FOR p1_idx IN 1..3 LOOP
        FOR p2_idx IN (p1_idx + 1)..4 LOOP
          INSERT INTO tournament_matches (
            tournament_id,
            group_id,
            player1_id,
            player2_id,
            status,
            phase
          ) VALUES (
            NEW.tournament_id,
            group_ids[current_group_idx],
            group_players[p1_idx],
            group_players[p2_idx],
            'scheduled',
            'group'
          );
        END LOOP;
      END LOOP;
    END;
  END LOOP;
  
  RAISE NOTICE '✅ Partite di girone create (24 partite totali)';
  RAISE NOTICE '🎾 TORNEO AVVIATO AUTOMATICAMENTE!';
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop del trigger esistente se presente
DROP TRIGGER IF EXISTS trigger_auto_start_tournament ON tournaments_user;

-- Crea il trigger che si attiva quando un giocatore si iscrive
CREATE TRIGGER trigger_auto_start_tournament
AFTER INSERT ON tournaments_user
FOR EACH ROW
EXECUTE FUNCTION auto_start_tournament_with_groups();

-- Messaggio finale
DO $$
BEGIN
  RAISE NOTICE '✅ Trigger automatico configurato!';
  RAISE NOTICE 'Quando il 16° giocatore si iscrive:';
  RAISE NOTICE '  1. Status torneo → in_progress';
  RAISE NOTICE '  2. Crea 4 gironi (A, B, C, D)';
  RAISE NOTICE '  3. Distribuisce 4 giocatori per girone';
  RAISE NOTICE '  4. Crea 24 partite di girone (6 per girone)';
END $$;
