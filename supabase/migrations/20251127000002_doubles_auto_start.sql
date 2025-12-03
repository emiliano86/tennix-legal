-- Sistema automatico per avviare tornei di doppio quando ci sono 16 coppie
-- Crea gironi automaticamente e gestisce la fase eliminatoria

-- Funzione per avviare automaticamente il torneo di doppio
CREATE OR REPLACE FUNCTION auto_start_doubles_tournament()
RETURNS TRIGGER AS $$
DECLARE
  pair_count INTEGER;
  max_pairs INTEGER := 16;
  tournament_type TEXT;
  existing_groups_count INTEGER;
  shuffled_pairs UUID[];
  group_id_a UUID;
  group_id_b UUID;
  group_id_c UUID;
  group_id_d UUID;
  group_ids UUID[];
  pair_idx INTEGER;
  current_group_idx INTEGER;
  p1_idx INTEGER;
  p2_idx INTEGER;
  group_pairs UUID[];
BEGIN
  RAISE NOTICE '=== TRIGGER: Verifica avvio torneo doppio ===';
  
  -- 1. Verifica che sia un torneo di doppio
  SELECT type INTO tournament_type
  FROM tournaments
  WHERE id = NEW.tournament_id;
  
  IF tournament_type IS NULL OR (tournament_type NOT ILIKE '%dopp%' AND tournament_type NOT ILIKE '%double%') THEN
    RAISE NOTICE '⚠️ Non è un torneo di doppio, skip';
    RETURN NEW;
  END IF;
  
  -- 2. Conta le coppie iscritte
  SELECT COUNT(DISTINCT id)
  INTO pair_count
  FROM tournament_pairs
  WHERE tournament_id = NEW.tournament_id;
  
  RAISE NOTICE '👥 Coppie iscritte: %/%', pair_count, max_pairs;
  
  -- 3. Verifica se ha raggiunto 16 coppie
  IF pair_count < max_pairs THEN
    RAISE NOTICE '⏳ Attendo altre % coppie', (max_pairs - pair_count);
    RETURN NEW;
  END IF;
  
  -- 4. Verifica se i gironi sono già stati creati
  SELECT COUNT(*)
  INTO existing_groups_count
  FROM tournament_groups
  WHERE tournament_id = NEW.tournament_id;
  
  IF existing_groups_count > 0 THEN
    RAISE NOTICE '⚠️ Gironi già esistenti (%), skip', existing_groups_count;
    RETURN NEW;
  END IF;
  
  RAISE NOTICE '🚀 AVVIO AUTOMATICO TORNEO DOPPIO!';
  
  -- 5. Aggiorna lo stato del torneo
  UPDATE tournaments
  SET status = 'in_progress',
      groups_created = true
  WHERE id = NEW.tournament_id;
  
  RAISE NOTICE '✅ Torneo aggiornato a in_progress';
  
  -- 6. Mischia casualmente le coppie
  SELECT ARRAY_AGG(id ORDER BY RANDOM())
  INTO shuffled_pairs
  FROM tournament_pairs
  WHERE tournament_id = NEW.tournament_id;
  
  RAISE NOTICE '🔀 Coppie mescolate';
  
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
  
  -- 8. Distribuisci le coppie nei gironi (4 coppie per girone)
  FOR pair_idx IN 1..16 LOOP
    current_group_idx := ((pair_idx - 1) / 4) + 1; -- 1,2,3,4
    
    INSERT INTO tournament_group_pairs (group_id, pair_id, points, matches_played, matches_won, matches_lost)
    VALUES (
      group_ids[current_group_idx],
      shuffled_pairs[pair_idx],
      0, 0, 0, 0
    );
  END LOOP;
  
  RAISE NOTICE '✅ Coppie distribuite nei gironi (4 per girone)';
  
  -- 9. Crea le partite per ogni girone (round robin - tutti contro tutti)
  FOR current_group_idx IN 1..4 LOOP
    -- Ottieni le 4 coppie del girone
    SELECT ARRAY_AGG(pair_id)
    INTO group_pairs
    FROM tournament_group_pairs
    WHERE group_id = group_ids[current_group_idx];
    
    -- Crea tutte le combinazioni (6 partite per girone)
    FOR p1_idx IN 1..3 LOOP
      FOR p2_idx IN (p1_idx + 1)..4 LOOP
        INSERT INTO tournament_doubles_matches (
          tournament_id,
          group_id,
          pair1_id,
          pair2_id,
          status,
          phase
        ) VALUES (
          NEW.tournament_id,
          group_ids[current_group_idx],
          group_pairs[p1_idx],
          group_pairs[p2_idx],
          'scheduled',
          'group'
        );
      END LOOP;
    END LOOP;
  END LOOP;
  
  RAISE NOTICE '✅ 24 partite create (6 per girone)';
  RAISE NOTICE '🎉 TORNEO DOPPIO AVVIATO CON SUCCESSO!';
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger che si attiva quando viene creata una nuova coppia
DROP TRIGGER IF EXISTS trigger_auto_start_doubles ON tournament_pairs;
CREATE TRIGGER trigger_auto_start_doubles
AFTER INSERT ON tournament_pairs
FOR EACH ROW
EXECUTE FUNCTION auto_start_doubles_tournament();

-- Funzione per completare fase a gironi e avviare eliminazione diretta
CREATE OR REPLACE FUNCTION complete_doubles_groups_and_start_knockout()
RETURNS void AS $$
DECLARE
  tournament_record RECORD;
  group_record RECORD;
  match_record RECORD;
  qualified_pairs UUID[] := '{}';
  top_pairs UUID[];
  knockout_exists INTEGER;
  pair1_sets_won INTEGER;
  pair2_sets_won INTEGER;
  match_winner_pair_id UUID;
BEGIN
  RAISE NOTICE '=== COMPLETAMENTO FASE GIRONI DOPPIO E AVVIO KNOCKOUT ===';
  
  -- Per ogni torneo di doppio in corso con partite di girone da completare
  FOR tournament_record IN
    SELECT DISTINCT t.id, t.name
    FROM tournaments t
    JOIN tournament_doubles_matches tdm ON t.id = tdm.tournament_id
    WHERE t.type ILIKE '%dopp%' OR t.type ILIKE '%double%'
      AND t.status = 'in_progress'
      AND tdm.phase = 'group'
      AND tdm.status = 'scheduled'
  LOOP
    RAISE NOTICE '';
    RAISE NOTICE '=== Torneo Doppio: % (ID: %) ===', tournament_record.name, tournament_record.id;
    
    -- 1. Completa tutte le partite di girone con risultati casuali
    RAISE NOTICE '📊 Completamento partite di girone...';
    
    FOR match_record IN
      SELECT id, pair1_id, pair2_id, group_id
      FROM tournament_doubles_matches
      WHERE tournament_id = tournament_record.id
        AND phase = 'group'
        AND status = 'scheduled'
    LOOP
      -- Genera risultato casuale per set
      -- Set 1 e 2: vincitore a 6 game (può essere 6-0, 6-1, ..., 7-5, 7-6)
      pair1_sets_won := 0;
      pair2_sets_won := 0;
      
      -- Set 1
      IF RANDOM() < 0.5 THEN
        pair1_sets_won := pair1_sets_won + 1;
        UPDATE tournament_doubles_matches
        SET set1_pair1_score = 6,
            set1_pair2_score = FLOOR(RANDOM() * 5)::INTEGER -- 0-4
        WHERE id = match_record.id;
      ELSE
        pair2_sets_won := pair2_sets_won + 1;
        UPDATE tournament_doubles_matches
        SET set1_pair1_score = FLOOR(RANDOM() * 5)::INTEGER, -- 0-4
            set1_pair2_score = 6
        WHERE id = match_record.id;
      END IF;
      
      -- Set 2
      IF RANDOM() < 0.5 THEN
        pair1_sets_won := pair1_sets_won + 1;
        UPDATE tournament_doubles_matches
        SET set2_pair1_score = 6,
            set2_pair2_score = FLOOR(RANDOM() * 5)::INTEGER
        WHERE id = match_record.id;
      ELSE
        pair2_sets_won := pair2_sets_won + 1;
        UPDATE tournament_doubles_matches
        SET set2_pair1_score = FLOOR(RANDOM() * 5)::INTEGER,
            set2_pair2_score = 6
        WHERE id = match_record.id;
      END IF;
      
      -- Se 1-1, serve il tie-break al 3° set
      IF pair1_sets_won = 1 AND pair2_sets_won = 1 THEN
        IF RANDOM() < 0.5 THEN
          match_winner_pair_id := match_record.pair1_id;
          UPDATE tournament_doubles_matches
          SET set3_pair1_score = 10,
              set3_pair2_score = FLOOR(RANDOM() * 8)::INTEGER + 0, -- 0-7
              winner_pair_id = match_winner_pair_id,
              status = 'completed'
          WHERE id = match_record.id;
        ELSE
          match_winner_pair_id := match_record.pair2_id;
          UPDATE tournament_doubles_matches
          SET set3_pair1_score = FLOOR(RANDOM() * 8)::INTEGER + 0,
              set3_pair2_score = 10,
              winner_pair_id = match_winner_pair_id,
              status = 'completed'
          WHERE id = match_record.id;
        END IF;
      ELSE
        -- Chi ha vinto 2 set vince la partita
        IF pair1_sets_won = 2 THEN
          match_winner_pair_id := match_record.pair1_id;
        ELSE
          match_winner_pair_id := match_record.pair2_id;
        END IF;
        
        UPDATE tournament_doubles_matches
        SET winner_pair_id = match_winner_pair_id,
            status = 'completed'
        WHERE id = match_record.id;
      END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Partite di girone completate';
    
    -- 2. Seleziona le prime 2 coppie di ogni girone
    RAISE NOTICE '';
    RAISE NOTICE '🏆 Selezione coppie qualificate...';
    
    FOR group_record IN
      SELECT id, group_name
      FROM tournament_groups
      WHERE tournament_id = tournament_record.id
      ORDER BY group_name
    LOOP
      SELECT ARRAY_AGG(pair_id)
      INTO top_pairs
      FROM (
        SELECT pair_id
        FROM tournament_group_pairs
        WHERE group_id = group_record.id
        ORDER BY points DESC, matches_won DESC, sets_won DESC, games_won DESC, pair_id
        LIMIT 2
      ) sub;
      
      qualified_pairs := qualified_pairs || top_pairs;
      
      RAISE NOTICE '  % → Qualificate: % coppie', group_record.group_name, array_length(top_pairs, 1);
    END LOOP;
    
    RAISE NOTICE '✅ Totale qualificate: % coppie', array_length(qualified_pairs, 1);
    
    -- 3. Crea il tabellone a eliminazione diretta (Quarti di finale)
    RAISE NOTICE '';
    RAISE NOTICE '🎾 Creazione tabellone eliminazione diretta...';
    
    -- Verifica che non esistano già partite knockout
    SELECT COUNT(*)
    INTO knockout_exists
    FROM tournament_doubles_matches
    WHERE tournament_id = tournament_record.id
      AND phase = 'knockout';
    
    IF knockout_exists > 0 THEN
      RAISE NOTICE '⚠️ Tabellone già esistente, skip';
      CONTINUE;
    END IF;
    
    -- Crea i quarti di finale (8 coppie → 4 partite)
    -- Accoppiamenti: 1A vs 2B, 1B vs 2A, 1C vs 2D, 1D vs 2C
    
    -- Quarto 1: 1° Girone A vs 2° Girone B
    INSERT INTO tournament_doubles_matches (
      tournament_id, pair1_id, pair2_id,
      status, phase, round
    ) VALUES (
      tournament_record.id,
      qualified_pairs[1], qualified_pairs[4],
      'scheduled', 'knockout', 'quarter_final'
    );
    
    -- Quarto 2: 1° Girone B vs 2° Girone A
    INSERT INTO tournament_doubles_matches (
      tournament_id, pair1_id, pair2_id,
      status, phase, round
    ) VALUES (
      tournament_record.id,
      qualified_pairs[3], qualified_pairs[2],
      'scheduled', 'knockout', 'quarter_final'
    );
    
    -- Quarto 3: 1° Girone C vs 2° Girone D
    INSERT INTO tournament_doubles_matches (
      tournament_id, pair1_id, pair2_id,
      status, phase, round
    ) VALUES (
      tournament_record.id,
      qualified_pairs[5], qualified_pairs[8],
      'scheduled', 'knockout', 'quarter_final'
    );
    
    -- Quarto 4: 1° Girone D vs 2° Girone C
    INSERT INTO tournament_doubles_matches (
      tournament_id, pair1_id, pair2_id,
      status, phase, round
    ) VALUES (
      tournament_record.id,
      qualified_pairs[7], qualified_pairs[6],
      'scheduled', 'knockout', 'quarter_final'
    );
    
    RAISE NOTICE '✅ 4 quarti di finale creati';
    RAISE NOTICE '🎉 FASE A GIRONI COMPLETATA - KNOCKOUT AVVIATO!';
  END LOOP;
  
  RAISE NOTICE '';
  RAISE NOTICE '=== OPERAZIONE COMPLETATA ===';
END;
$$ LANGUAGE plpgsql;

-- Funzione per generare automaticamente semifinali quando i quarti sono completati
CREATE OR REPLACE FUNCTION generate_doubles_semifinals()
RETURNS TRIGGER AS $$
DECLARE
  quarter1_winner UUID;
  quarter2_winner UUID;
  quarter3_winner UUID;
  quarter4_winner UUID;
  completed_quarters INTEGER;
  semi1_exists INTEGER;
  semi2_exists INTEGER;
BEGIN
  -- Esegui solo se la partita è stata appena completata
  IF NEW.status = 'completed' AND OLD.status != 'completed' AND NEW.phase = 'knockout' AND NEW.round = 'quarter_final' THEN
    
    RAISE NOTICE '🎾 Quarto di finale completato per torneo %', NEW.tournament_id;
    
    -- Conta quanti quarti sono completati
    SELECT COUNT(*)
    INTO completed_quarters
    FROM tournament_doubles_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'quarter_final'
      AND status = 'completed';
    
    RAISE NOTICE '  Quarti completati: %/4', completed_quarters;
    
    -- Ottieni i vincitori dei quarti in ordine
    SELECT winner_pair_id INTO quarter1_winner
    FROM tournament_doubles_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'quarter_final'
      AND status = 'completed'
    ORDER BY created_at, id
    LIMIT 1 OFFSET 0;
    
    SELECT winner_pair_id INTO quarter2_winner
    FROM tournament_doubles_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'quarter_final'
      AND status = 'completed'
    ORDER BY created_at, id
    LIMIT 1 OFFSET 1;
    
    SELECT winner_pair_id INTO quarter3_winner
    FROM tournament_doubles_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'quarter_final'
      AND status = 'completed'
    ORDER BY created_at, id
    LIMIT 1 OFFSET 2;
    
    SELECT winner_pair_id INTO quarter4_winner
    FROM tournament_doubles_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'quarter_final'
      AND status = 'completed'
    ORDER BY created_at, id
    LIMIT 1 OFFSET 3;
    
    -- Verifica quante semifinali esistono già
    SELECT COUNT(*) INTO semi1_exists
    FROM tournament_doubles_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'semi_final';
    
    -- Crea/Aggiorna Semifinale 1 (Q1 winner vs Q2 winner)
    IF (quarter1_winner IS NOT NULL OR quarter2_winner IS NOT NULL) THEN
      IF semi1_exists = 0 THEN
        INSERT INTO tournament_doubles_matches (
          tournament_id, pair1_id, pair2_id,
          status, phase, round
        ) VALUES (
          NEW.tournament_id,
          quarter1_winner,
          quarter2_winner,
          CASE WHEN quarter1_winner IS NOT NULL AND quarter2_winner IS NOT NULL 
               THEN 'scheduled' 
               ELSE 'pending' 
          END,
          'knockout', 'semi_final'
        );
        RAISE NOTICE '✅ Semifinale 1 creata';
      ELSE
        UPDATE tournament_doubles_matches
        SET 
          pair1_id = quarter1_winner,
          pair2_id = quarter2_winner,
          status = CASE WHEN quarter1_winner IS NOT NULL AND quarter2_winner IS NOT NULL 
                        THEN 'scheduled' 
                        ELSE 'pending' 
                   END
        WHERE id = (
          SELECT id FROM tournament_doubles_matches
          WHERE tournament_id = NEW.tournament_id
            AND phase = 'knockout'
            AND round = 'semi_final'
          ORDER BY id
          LIMIT 1
        );
        RAISE NOTICE '✅ Semifinale 1 aggiornata';
      END IF;
    END IF;
    
    -- Crea/Aggiorna Semifinale 2 (Q3 winner vs Q4 winner)
    IF (quarter3_winner IS NOT NULL OR quarter4_winner IS NOT NULL) THEN
      SELECT COUNT(*) INTO semi2_exists
      FROM tournament_doubles_matches
      WHERE tournament_id = NEW.tournament_id
        AND phase = 'knockout'
        AND round = 'semi_final';
      
      IF semi2_exists < 2 THEN
        INSERT INTO tournament_doubles_matches (
          tournament_id, pair1_id, pair2_id,
          status, phase, round
        ) VALUES (
          NEW.tournament_id,
          quarter3_winner,
          quarter4_winner,
          CASE WHEN quarter3_winner IS NOT NULL AND quarter4_winner IS NOT NULL 
               THEN 'scheduled' 
               ELSE 'pending' 
          END,
          'knockout', 'semi_final'
        );
        RAISE NOTICE '✅ Semifinale 2 creata';
      ELSIF semi2_exists = 2 THEN
        UPDATE tournament_doubles_matches
        SET 
          pair1_id = quarter3_winner,
          pair2_id = quarter4_winner,
          status = CASE WHEN quarter3_winner IS NOT NULL AND quarter4_winner IS NOT NULL 
                        THEN 'scheduled' 
                        ELSE 'pending' 
                   END
        WHERE id = (
          SELECT id FROM tournament_doubles_matches
          WHERE tournament_id = NEW.tournament_id
            AND phase = 'knockout'
            AND round = 'semi_final'
          ORDER BY id
          LIMIT 1 OFFSET 1
        );
        RAISE NOTICE '✅ Semifinale 2 aggiornata';
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_generate_doubles_semifinals ON tournament_doubles_matches;
CREATE TRIGGER trigger_generate_doubles_semifinals
AFTER UPDATE ON tournament_doubles_matches
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.winner_pair_id IS DISTINCT FROM NEW.winner_pair_id)
EXECUTE FUNCTION generate_doubles_semifinals();

-- Funzione per generare finale quando le semifinali sono completate
CREATE OR REPLACE FUNCTION generate_doubles_final()
RETURNS TRIGGER AS $$
DECLARE
  semi_winners UUID[];
  final_exists INTEGER;
  completed_semis INTEGER;
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' AND NEW.phase = 'knockout' AND NEW.round = 'semi_final' THEN
    
    RAISE NOTICE '🎾 Semifinale completata per torneo %', NEW.tournament_id;
    
    -- Conta semifinali completate
    SELECT COUNT(*)
    INTO completed_semis
    FROM tournament_doubles_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'semi_final'
      AND status = 'completed';
    
    RAISE NOTICE '  Semifinali completate: %/2', completed_semis;
    
    -- Se entrambe le semifinali sono completate, crea la finale
    IF completed_semis = 2 THEN
      -- Verifica se la finale esiste già
      SELECT COUNT(*)
      INTO final_exists
      FROM tournament_doubles_matches
      WHERE tournament_id = NEW.tournament_id
        AND phase = 'knockout'
        AND round = 'final';
      
      IF final_exists = 0 THEN
        RAISE NOTICE '🏆 Generazione finale per torneo doppio %', NEW.tournament_id;
        
        -- Ottieni i vincitori delle semifinali
        SELECT ARRAY_AGG(winner_pair_id ORDER BY created_at, id) INTO semi_winners
        FROM tournament_doubles_matches
        WHERE tournament_id = NEW.tournament_id
          AND phase = 'knockout'
          AND round = 'semi_final'
          AND status = 'completed';
        
        -- Crea la finale
        INSERT INTO tournament_doubles_matches (
          tournament_id, pair1_id, pair2_id,
          status, phase, round
        ) VALUES (
          NEW.tournament_id,
          semi_winners[1], semi_winners[2],
          'scheduled', 'knockout', 'final'
        );
        
        RAISE NOTICE '✅ Finale creata!';
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_generate_doubles_final ON tournament_doubles_matches;
CREATE TRIGGER trigger_generate_doubles_final
AFTER UPDATE ON tournament_doubles_matches
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.winner_pair_id IS DISTINCT FROM NEW.winner_pair_id)
EXECUTE FUNCTION generate_doubles_final();

DO $$
BEGIN
  RAISE NOTICE '✅ Sistema automatico tornei doppio configurato!';
  RAISE NOTICE '📋 Funzionalità:';
  RAISE NOTICE '  - Avvio automatico con 16 coppie';
  RAISE NOTICE '  - Creazione gironi (4x4 coppie)';
  RAISE NOTICE '  - Fase eliminatoria automatica';
  RAISE NOTICE '  - Semifinali e finale automatiche';
END $$;
