-- Script manuale per avviare tornei che hanno già 16 giocatori ma non sono partiti
-- Esegui questo script se hai già 16 giocatori iscritti ma i gironi non sono stati creati

DO $$
DECLARE
  tournament_record RECORD;
  participant_count INTEGER;
  existing_groups_count INTEGER;
  shuffled_participants UUID[];
  group_id_a UUID;
  group_id_b UUID;
  group_id_c UUID;
  group_id_d UUID;
  group_ids UUID[];
  player_idx INTEGER;
  current_group_idx INTEGER;
  p1_idx INTEGER;
  p2_idx INTEGER;
  group_players UUID[];
BEGIN
  RAISE NOTICE '=== AVVIO MANUALE TORNEI CON 16 GIOCATORI ===';
  
  -- Trova tutti i tornei aperti con esattamente 16 giocatori
  FOR tournament_record IN 
    SELECT t.id, t.name, COUNT(tu.user_id) as participants
    FROM tournaments t
    LEFT JOIN tournaments_user tu ON t.id = tu.tournament_id AND tu.active = true
    WHERE t.status = 'open'
    GROUP BY t.id, t.name
    HAVING COUNT(tu.user_id) = 16
  LOOP
    RAISE NOTICE '';
    RAISE NOTICE '=== Torneo: % (ID: %) ===', tournament_record.name, tournament_record.id;
    RAISE NOTICE 'Partecipanti: %', tournament_record.participants;
    
    -- Verifica se i gironi sono già stati creati
    SELECT COUNT(*) 
    INTO existing_groups_count
    FROM tournament_groups 
    WHERE tournament_id = tournament_record.id;
    
    IF existing_groups_count > 0 THEN
      RAISE NOTICE '⚠️ Gironi già esistenti (%), salto...', existing_groups_count;
      CONTINUE;
    END IF;
    
    RAISE NOTICE '✅ Avvio torneo...';
    
    -- 1. Aggiorna stato torneo
    UPDATE tournaments 
    SET status = 'in_progress',
        actual_start_date = NOW()
    WHERE id = tournament_record.id;
    
    RAISE NOTICE '📝 Status → in_progress';
    
    -- 2. Ottieni partecipanti in ordine casuale
    SELECT ARRAY_AGG(user_id ORDER BY RANDOM())
    INTO shuffled_participants
    FROM tournaments_user
    WHERE tournament_id = tournament_record.id 
      AND active = true;
    
    RAISE NOTICE '🔀 Partecipanti mescolati';
    
    -- 3. Crea i 4 gironi
    INSERT INTO tournament_groups (tournament_id, group_name)
    VALUES (tournament_record.id, 'Girone A')
    RETURNING id INTO group_id_a;
    
    INSERT INTO tournament_groups (tournament_id, group_name)
    VALUES (tournament_record.id, 'Girone B')
    RETURNING id INTO group_id_b;
    
    INSERT INTO tournament_groups (tournament_id, group_name)
    VALUES (tournament_record.id, 'Girone C')
    RETURNING id INTO group_id_c;
    
    INSERT INTO tournament_groups (tournament_id, group_name)
    VALUES (tournament_record.id, 'Girone D')
    RETURNING id INTO group_id_d;
    
    group_ids := ARRAY[group_id_a, group_id_b, group_id_c, group_id_d];
    
    RAISE NOTICE '✅ 4 Gironi creati';
    
    -- 4. Distribuisci giocatori (4 per girone)
    FOR player_idx IN 1..16 LOOP
      current_group_idx := ((player_idx - 1) / 4) + 1;
      
      INSERT INTO tournament_group_members (group_id, player_id, points, matches_played, matches_won, matches_lost)
      VALUES (
        group_ids[current_group_idx],
        shuffled_participants[player_idx],
        0, 0, 0, 0
      );
    END LOOP;
    
    RAISE NOTICE '✅ Giocatori distribuiti';
    
    -- 5. Crea partite per ogni girone
    FOR current_group_idx IN 1..4 LOOP
      -- Ottieni i 4 giocatori del girone
      SELECT ARRAY_AGG(player_id)
      INTO group_players
      FROM tournament_group_members
      WHERE group_id = group_ids[current_group_idx];
      
      -- Crea tutte le combinazioni (6 partite per girone)
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
            tournament_record.id,
            group_ids[current_group_idx],
            group_players[p1_idx],
            group_players[p2_idx],
            'scheduled',
            'group'
          );
        END LOOP;
      END LOOP;
    END LOOP;
    
    RAISE NOTICE '✅ 24 partite create (6 per girone)';
    RAISE NOTICE '🎾 TORNEO % AVVIATO!', tournament_record.name;
  END LOOP;
  
  RAISE NOTICE '';
  RAISE NOTICE '=== PROCESSO COMPLETATO ===';
END $$;
