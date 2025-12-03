-- Script da eseguire UNA SOLA VOLTA per creare nuovi tornei 
-- per quelli che hanno già groups_created = true

DO $$
DECLARE
  existing_tournament RECORD;
  new_registration_end TIMESTAMP;
  new_start_date TIMESTAMP;
  existing_count INTEGER;
BEGIN
  RAISE NOTICE '=== Creazione tornei successivi per tornei esistenti ===';
  
  -- Per ogni torneo che ha già groups_created = true
  FOR existing_tournament IN 
    SELECT * FROM tournaments 
    WHERE groups_created = true
  LOOP
    RAISE NOTICE 'Verifico torneo: %', existing_tournament.name;
    
    -- Controlla se esiste già un torneo futuro con stesso nome/tipo
    SELECT COUNT(*) INTO existing_count
    FROM tournaments
    WHERE name = existing_tournament.name 
      AND type = existing_tournament.type 
      AND groups_created = false
      AND id != existing_tournament.id;
    
    IF existing_count > 0 THEN
      RAISE NOTICE '  Torneo successivo già esistente, skip';
      CONTINUE;
    END IF;
    
    -- Calcola le nuove date (sempre 7 giorni di durata)
    new_registration_end := NOW() + INTERVAL '7 days';
    new_start_date := NOW() + INTERVAL '8 days';
    
    RAISE NOTICE '  Creazione nuovo torneo con date: reg_end=%, start=%', 
      new_registration_end, new_start_date;
    
    -- Crea il nuovo torneo
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
      existing_tournament.name,
      existing_tournament.type,
      'open',
      new_start_date,
      new_registration_end,
      existing_tournament.location,
      existing_tournament.regulation,
      existing_tournament.image_url,
      false,
      NOW()
    );
    
    RAISE NOTICE '  ✅ Nuovo torneo creato!';
    
  END LOOP;
  
  RAISE NOTICE '=== Completato ===';
END $$;
