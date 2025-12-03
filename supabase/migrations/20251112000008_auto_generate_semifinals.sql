-- Funzione per generare/aggiornare le semifinali progressivamente quando i quarti vengono completati

CREATE OR REPLACE FUNCTION generate_semifinals()
RETURNS TRIGGER AS $$
DECLARE
  tournament_rec RECORD;
  quarter1_winner UUID;
  quarter2_winner UUID;
  quarter3_winner UUID;
  quarter4_winner UUID;
  semi1_exists INTEGER;
  semi2_exists INTEGER;
BEGIN
  -- Verifica che sia una partita knockout quarter_final
  IF NEW.phase = 'knockout' AND NEW.round = 'quarter_final' THEN
    
    -- Verifica solo se completata per logging
    IF NEW.status = 'completed' THEN
      RAISE NOTICE '🎾 Quarto di finale completato per torneo %', NEW.tournament_id;
    END IF;
    
    -- Ottieni i vincitori dei quarti in ordine di creazione (created_at)
    -- Q1: 1°A vs 2°B, Q2: 1°B vs 2°A, Q3: 1°C vs 2°D, Q4: 1°D vs 2°C
    SELECT winner_id INTO quarter1_winner
    FROM tournament_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'quarter_final'
      AND status = 'completed'
    ORDER BY created_at, id
    LIMIT 1 OFFSET 0;
    
    SELECT winner_id INTO quarter2_winner
    FROM tournament_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'quarter_final'
      AND status = 'completed'
    ORDER BY created_at, id
    LIMIT 1 OFFSET 1;
    
    SELECT winner_id INTO quarter3_winner
    FROM tournament_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'quarter_final'
      AND status = 'completed'
    ORDER BY created_at, id
    LIMIT 1 OFFSET 2;
    
    SELECT winner_id INTO quarter4_winner
    FROM tournament_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'quarter_final'
      AND status = 'completed'
    ORDER BY created_at, id
    LIMIT 1 OFFSET 3;
    
    -- Verifica se la semifinale 1 esiste
    SELECT COUNT(*) INTO semi1_exists
    FROM tournament_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'semi_final';
    
    -- Se almeno uno tra Q1 o Q2 è completato, crea/aggiorna la semifinale 1
    IF (quarter1_winner IS NOT NULL OR quarter2_winner IS NOT NULL) THEN
      IF semi1_exists = 0 THEN
        -- Crea la semifinale 1
        INSERT INTO tournament_matches (
          tournament_id, player1_id, player2_id,
          status, phase, round
        ) VALUES (
          NEW.tournament_id,
          quarter1_winner,  -- Può essere NULL se Q1 non è finito
          quarter2_winner,  -- Può essere NULL se Q2 non è finito
          CASE WHEN quarter1_winner IS NOT NULL AND quarter2_winner IS NOT NULL 
               THEN 'scheduled' 
               ELSE 'pending' 
          END,
          'knockout', 'semi_final'
        );
        RAISE NOTICE '✅ Semifinale 1 creata (Q1 winner vs Q2 winner)';
      ELSE
        -- Aggiorna la semifinale 1 con i vincitori disponibili
        UPDATE tournament_matches
        SET 
          player1_id = quarter1_winner,
          player2_id = quarter2_winner,
          status = CASE WHEN quarter1_winner IS NOT NULL AND quarter2_winner IS NOT NULL 
                        THEN 'scheduled' 
                        ELSE 'pending' 
                   END
        WHERE id = (
          SELECT id FROM tournament_matches
          WHERE tournament_id = NEW.tournament_id
            AND phase = 'knockout'
            AND round = 'semi_final'
          ORDER BY id
          LIMIT 1
        );
        RAISE NOTICE '✅ Semifinale 1 aggiornata';
      END IF;
    END IF;
    
    -- Verifica se la semifinale 2 esiste
    SELECT COUNT(*) INTO semi2_exists
    FROM tournament_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'semi_final';
    
    -- Se almeno uno tra Q3 o Q4 è completato, crea/aggiorna la semifinale 2
    IF (quarter3_winner IS NOT NULL OR quarter4_winner IS NOT NULL) THEN
      IF semi2_exists < 2 THEN
        -- Crea la semifinale 2 (solo se ne esiste meno di 2)
        INSERT INTO tournament_matches (
          tournament_id, player1_id, player2_id,
          status, phase, round
        ) VALUES (
          NEW.tournament_id,
          quarter3_winner,  -- Può essere NULL
          quarter4_winner,  -- Può essere NULL
          CASE WHEN quarter3_winner IS NOT NULL AND quarter4_winner IS NOT NULL 
               THEN 'scheduled' 
               ELSE 'pending' 
          END,
          'knockout', 'semi_final'
        );
        RAISE NOTICE '✅ Semifinale 2 creata (Q3 winner vs Q4 winner)';
      ELSIF semi2_exists = 2 THEN
        -- Aggiorna la semifinale 2 (la seconda in ordine di ID, OFFSET 1)
        UPDATE tournament_matches
        SET 
          player1_id = quarter3_winner,
          player2_id = quarter4_winner,
          status = CASE WHEN quarter3_winner IS NOT NULL AND quarter4_winner IS NOT NULL 
                        THEN 'scheduled' 
                        ELSE 'pending' 
                   END
        WHERE id = (
          SELECT id FROM tournament_matches
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

-- Trigger che genera le semifinali quando un quarto viene completato
DROP TRIGGER IF EXISTS trigger_generate_semifinals ON tournament_matches;
CREATE TRIGGER trigger_generate_semifinals
AFTER UPDATE ON tournament_matches
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.winner_id IS DISTINCT FROM NEW.winner_id)
EXECUTE FUNCTION generate_semifinals();


-- Funzione per generare automaticamente la finale quando entrambe le semifinali sono completate

CREATE OR REPLACE FUNCTION generate_final()
RETURNS TRIGGER AS $$
DECLARE
  semis_completed INTEGER;
  final_exists INTEGER;
  semi_winners UUID[];
BEGIN
  -- Verifica che sia una semifinale completata
  IF NEW.phase = 'knockout' AND NEW.round = 'semi_final' AND NEW.status = 'completed' THEN
    
    -- Conta quante semifinali sono completate
    SELECT COUNT(*) INTO semis_completed
    FROM tournament_matches
    WHERE tournament_id = NEW.tournament_id
      AND phase = 'knockout'
      AND round = 'semi_final'
      AND status = 'completed';
    
    RAISE NOTICE 'Semifinali completate: %', semis_completed;
    
    -- Se entrambe le semifinali sono completate
    IF semis_completed = 2 THEN
      
      -- Verifica che la finale non esista già
      SELECT COUNT(*) INTO final_exists
      FROM tournament_matches
      WHERE tournament_id = NEW.tournament_id
        AND phase = 'knockout'
        AND round = 'final';
      
      IF final_exists = 0 THEN
        RAISE NOTICE '🏆 Generazione finale per torneo %', NEW.tournament_id;
        
        -- Ottieni i vincitori delle semifinali in ordine di creazione
        SELECT ARRAY_AGG(winner_id ORDER BY created_at, id) INTO semi_winners
        FROM tournament_matches
        WHERE tournament_id = NEW.tournament_id
          AND phase = 'knockout'
          AND round = 'semi_final'
          AND status = 'completed';
        
        -- Finale: Vincitore SF1 vs Vincitore SF2
        INSERT INTO tournament_matches (
          tournament_id, player1_id, player2_id,
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

-- Trigger che genera la finale quando una semifinale viene completata
DROP TRIGGER IF EXISTS trigger_generate_final ON tournament_matches;
CREATE TRIGGER trigger_generate_final
AFTER UPDATE ON tournament_matches
FOR EACH ROW
WHEN (NEW.phase = 'knockout' AND NEW.round = 'semi_final' AND NEW.status = 'completed' AND OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION generate_final();


-- Funzione per completare il torneo quando la finale viene completata

CREATE OR REPLACE FUNCTION complete_tournament()
RETURNS TRIGGER AS $$
DECLARE
  tournament_record RECORD;
  new_registration_end TIMESTAMP;
  new_start_date TIMESTAMP;
  existing_upcoming_count INTEGER;
BEGIN
  -- Verifica che sia la finale completata
  IF NEW.phase = 'knockout' AND NEW.round = 'final' AND NEW.status = 'completed' THEN
    
    RAISE NOTICE '🏆 Finale completata! Chiudo il torneo %', NEW.tournament_id;
    
    -- Ottieni i dati del torneo corrente
    SELECT * INTO tournament_record
    FROM tournaments
    WHERE id = NEW.tournament_id;
    
    -- Aggiorna lo stato del torneo a 'completed'
    UPDATE tournaments
    SET status = 'completed'
    WHERE id = NEW.tournament_id
      AND status = 'in_progress';
    
    RAISE NOTICE '✅ Torneo completato!';
    
    -- Verifica se esiste già un torneo "open" con lo stesso nome e tipo
    SELECT COUNT(*) INTO existing_upcoming_count
    FROM tournaments
    WHERE name = tournament_record.name 
      AND type = tournament_record.type 
      AND status = 'open'
      AND groups_created = false;
    
    IF existing_upcoming_count > 0 THEN
      RAISE NOTICE '⚠️ Torneo successivo già esistente, uscita';
      RETURN NEW;
    END IF;
    
    -- Calcola le nuove date (7 giorni di iscrizioni + inizio)
    new_registration_end := NOW() + INTERVAL '7 days';
    new_start_date := NOW() + INTERVAL '8 days';
    
    RAISE NOTICE '🎾 Creazione nuovo torneo: reg_end=%, start=%', new_registration_end, new_start_date;
    
    -- Crea il nuovo torneo con gli stessi parametri
    INSERT INTO tournaments (
      name,
      type,
      status,
      start_date,
      registration_end,
      location,
      regulation,
      image_url,
      groups_created,
      created_at
    ) VALUES (
      tournament_record.name,
      tournament_record.type,
      'open',
      new_start_date,
      new_registration_end,
      tournament_record.location,
      tournament_record.regulation,
      tournament_record.image_url,
      false,
      NOW()
    );
    
    RAISE NOTICE '✅ Nuovo torneo creato automaticamente!';
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger che completa il torneo quando la finale viene completata
DROP TRIGGER IF EXISTS trigger_complete_tournament ON tournament_matches;
CREATE TRIGGER trigger_complete_tournament
AFTER UPDATE ON tournament_matches
FOR EACH ROW
WHEN (NEW.phase = 'knockout' AND NEW.round = 'final' AND NEW.status = 'completed' AND OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION complete_tournament();


-- Funzione per archiviare automaticamente i tornei completati dopo 7 giorni

CREATE OR REPLACE FUNCTION archive_old_completed_tournaments()
RETURNS void AS $$
DECLARE
  archived_count INTEGER;
BEGIN
  -- Archivia i tornei completati da più di 7 giorni
  UPDATE tournaments
  SET status = 'archived'
  WHERE status = 'completed'
    AND created_at < NOW() - INTERVAL '7 days';
  
  GET DIAGNOSTICS archived_count = ROW_COUNT;
  
  IF archived_count > 0 THEN
    RAISE NOTICE '📦 % tornei archiviati automaticamente', archived_count;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Nota: Per eseguire questa funzione automaticamente, puoi usare pg_cron o chiamarla manualmente
-- Esempio manuale: SELECT archive_old_completed_tournaments();
-- Oppure creare un job con pg_cron (se disponibile su Supabase):
