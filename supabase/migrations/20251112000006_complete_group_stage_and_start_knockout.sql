-- Script per completare la fase a gironi con risultati casuali
-- e avviare automaticamente la fase a eliminazione diretta

DO $$
DECLARE
  tournament_record RECORD;
  match_record RECORD;
  score1 INTEGER;
  score2 INTEGER;
  match_winner_id UUID;
  group_record RECORD;
  qualified_players UUID[];
  quarter_matches INTEGER := 0;
BEGIN
  RAISE NOTICE '=== COMPLETAMENTO FASE A GIRONI E AVVIO KNOCKOUT ===';
  RAISE NOTICE '';
  
  -- Trova tutti i tornei in corso con partite di girone non completate
  FOR tournament_record IN 
    SELECT DISTINCT t.id, t.name
    FROM tournaments t
    INNER JOIN tournament_matches tm ON t.id = tm.tournament_id
    WHERE t.status = 'in_progress'
      AND tm.phase = 'group'
      AND tm.status = 'scheduled'
  LOOP
    RAISE NOTICE '=== Torneo: % (ID: %) ===', tournament_record.name, tournament_record.id;
    
    -- 1. Completa tutte le partite di girone con risultati casuali
    RAISE NOTICE '📊 Completamento partite di girone...';
    
    FOR match_record IN
      SELECT id, player1_id, player2_id, group_id
      FROM tournament_matches
      WHERE tournament_id = tournament_record.id
        AND phase = 'group'
        AND status = 'scheduled'
    LOOP
      -- Genera punteggi casuali (6-0, 6-1, 6-2, 6-3, 6-4, 7-5, 7-6)
      score1 := 6;
      score2 := FLOOR(RANDOM() * 7)::INTEGER; -- 0-6
      
      -- Se il punteggio è 6-6, fai 7-6
      IF score2 = 6 THEN
        score1 := 7;
        score2 := CASE WHEN RANDOM() < 0.5 THEN 5 ELSE 6 END;
      END IF;
      
      -- Decidi casualmente chi vince (50% probabilità per ciascuno)
      IF RANDOM() < 0.5 THEN
        match_winner_id := match_record.player1_id;
        -- Player1 vince: mantieni i punteggi
      ELSE
        match_winner_id := match_record.player2_id;
        -- Player2 vince: inverti i punteggi
        DECLARE temp INTEGER;
        BEGIN
          temp := score1;
          score1 := score2;
          score2 := temp;
        END;
      END IF;
      
      -- Aggiorna la partita
      UPDATE tournament_matches
      SET 
        status = 'completed',
        player1_score = score1,
        player2_score = score2,
        winner_id = match_winner_id
      WHERE id = match_record.id;
      
      -- Aggiorna le statistiche dei giocatori nel girone
      -- Player 1
      UPDATE tournament_group_members
      SET 
        matches_played = matches_played + 1,
        matches_won = matches_won + CASE WHEN match_winner_id = match_record.player1_id THEN 1 ELSE 0 END,
        matches_lost = matches_lost + CASE WHEN match_winner_id = match_record.player2_id THEN 1 ELSE 0 END,
        points = points + CASE WHEN match_winner_id = match_record.player1_id THEN 10 ELSE 0 END
      WHERE group_id = match_record.group_id
        AND player_id = match_record.player1_id;
      
      -- Player 2
      UPDATE tournament_group_members
      SET 
        matches_played = matches_played + 1,
        matches_won = matches_won + CASE WHEN match_winner_id = match_record.player2_id THEN 1 ELSE 0 END,
        matches_lost = matches_lost + CASE WHEN match_winner_id = match_record.player1_id THEN 1 ELSE 0 END,
        points = points + CASE WHEN match_winner_id = match_record.player2_id THEN 10 ELSE 0 END
      WHERE group_id = match_record.group_id
        AND player_id = match_record.player2_id;
    END LOOP;
    
    RAISE NOTICE '✅ Partite di girone completate';
    
    -- 2. Identifica i primi 2 di ogni girone
    RAISE NOTICE '';
    RAISE NOTICE '🏆 Qualificazione primi 2 per girone...';
    
    qualified_players := ARRAY[]::UUID[];
    
    FOR group_record IN
      SELECT id, group_name
      FROM tournament_groups
      WHERE tournament_id = tournament_record.id
      ORDER BY group_name
    LOOP
      DECLARE
        top_players UUID[];
      BEGIN
        -- Ottieni i primi 2 giocatori del girone ordinati per punti
        SELECT ARRAY_AGG(player_id)
        INTO top_players
        FROM (
          SELECT player_id
          FROM tournament_group_members
          WHERE group_id = group_record.id
          ORDER BY points DESC, matches_won DESC, player_id
          LIMIT 2
        ) sub;
        
        qualified_players := qualified_players || top_players;
        
        RAISE NOTICE '  % → Qualificati: % giocatori', group_record.group_name, array_length(top_players, 1);
      END;
    END LOOP;
    
    RAISE NOTICE '✅ Totale qualificati: % giocatori', array_length(qualified_players, 1);
    
    -- 3. Crea il tabellone a eliminazione diretta (Quarti di finale)
    RAISE NOTICE '';
    RAISE NOTICE '🎾 Creazione tabellone eliminazione diretta...';
    
    -- Verifica che non esistano già partite knockout
    DECLARE knockout_exists INTEGER;
    BEGIN
      SELECT COUNT(*)
      INTO knockout_exists
      FROM tournament_matches
      WHERE tournament_id = tournament_record.id
        AND phase = 'knockout';
      
      IF knockout_exists > 0 THEN
        RAISE NOTICE '⚠️ Tabellone già esistente, salto creazione';
        CONTINUE;
      END IF;
    END;
    
    -- Crea i quarti di finale (8 giocatori → 4 partite)
    -- Accoppiamenti: 1A vs 2B, 1B vs 2A, 1C vs 2D, 1D vs 2C
    
    -- Quarto 1: 1° Girone A vs 2° Girone B
    INSERT INTO tournament_matches (
      tournament_id, player1_id, player2_id, 
      status, phase, round
    ) VALUES (
      tournament_record.id, 
      qualified_players[1], qualified_players[4],
      'scheduled', 'knockout', 'quarter_final'
    );
    
    -- Quarto 2: 1° Girone B vs 2° Girone A
    INSERT INTO tournament_matches (
      tournament_id, player1_id, player2_id,
      status, phase, round
    ) VALUES (
      tournament_record.id,
      qualified_players[3], qualified_players[2],
      'scheduled', 'knockout', 'quarter_final'
    );
    
    -- Quarto 3: 1° Girone C vs 2° Girone D
    INSERT INTO tournament_matches (
      tournament_id, player1_id, player2_id,
      status, phase, round
    ) VALUES (
      tournament_record.id,
      qualified_players[5], qualified_players[8],
      'scheduled', 'knockout', 'quarter_final'
    );
    
    -- Quarto 4: 1° Girone D vs 2° Girone C
    INSERT INTO tournament_matches (
      tournament_id, player1_id, player2_id,
      status, phase, round
    ) VALUES (
      tournament_record.id,
      qualified_players[7], qualified_players[6],
      'scheduled', 'knockout', 'quarter_final'
    );
    
    RAISE NOTICE '✅ 4 quarti di finale creati';
    RAISE NOTICE '';
    RAISE NOTICE '🎾 FASE A GIRONI COMPLETATA!';
    RAISE NOTICE '🏆 TABELLONE A ELIMINAZIONE DIRETTA CREATO!';
    RAISE NOTICE '';
  END LOOP;
  
  RAISE NOTICE '=== PROCESSO COMPLETATO ===';
END $$;
