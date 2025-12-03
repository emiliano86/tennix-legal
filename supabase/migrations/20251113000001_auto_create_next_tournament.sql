-- Funzione per creare automaticamente il prossimo torneo quando uno inizia
CREATE OR REPLACE FUNCTION create_next_tournament()
RETURNS TRIGGER AS $$
DECLARE
  new_registration_end TIMESTAMP;
  new_start_date TIMESTAMP;
  existing_upcoming_count INTEGER;
BEGIN
  -- Esegui solo se groups_created passa da false a true
  IF OLD.groups_created = false AND NEW.groups_created = true THEN
    
    RAISE NOTICE 'Torneo % iniziato, creazione nuovo torneo...', NEW.name;
    
    -- Verifica se esiste già un torneo "upcoming" con lo stesso nome e tipo
    SELECT COUNT(*) INTO existing_upcoming_count
    FROM tournaments
    WHERE name = NEW.name 
      AND type = NEW.type 
      AND status = 'upcoming'
      AND groups_created = false;
    
    IF existing_upcoming_count > 0 THEN
      RAISE NOTICE 'Torneo successivo già esistente, uscita';
      RETURN NEW;
    END IF;
    
    -- Calcola le nuove date (sempre 7 giorni di durata)
    new_registration_end := NOW() + INTERVAL '7 days';
    new_start_date := NOW() + INTERVAL '8 days';
    
    RAISE NOTICE 'Nuove date: reg_end=%, start=%', new_registration_end, new_start_date;
    
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
      NEW.name,
      NEW.type,
      'open',
      new_start_date,
      new_registration_end,
      NEW.location,
      NEW.regulation,
      NEW.image_url,
      false,
      NOW()
    );
    
    RAISE NOTICE '✅ Nuovo torneo creato con successo!';
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger che esegue la funzione quando groups_created cambia
DROP TRIGGER IF EXISTS trigger_create_next_tournament ON tournaments;

CREATE TRIGGER trigger_create_next_tournament
  AFTER UPDATE OF groups_created ON tournaments
  FOR EACH ROW
  WHEN (OLD.groups_created IS DISTINCT FROM NEW.groups_created)
  EXECUTE FUNCTION create_next_tournament();
