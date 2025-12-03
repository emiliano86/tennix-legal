-- ========================================
-- FIX DEFINITIVO - Rimuovi trigger ambigui
-- ========================================

-- STEP 1: Rimuovi TUTTI i trigger da tournaments_user
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT trigger_name FROM information_schema.triggers 
              WHERE event_object_table = 'tournaments_user') 
    LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON tournaments_user CASCADE';
    END LOOP;
END $$;

-- STEP 2: Rimuovi le funzioni più comuni che causano ambiguità
DROP FUNCTION IF EXISTS check_tournament_capacity() CASCADE;
DROP FUNCTION IF EXISTS validate_tournament_registration() CASCADE;
DROP FUNCTION IF EXISTS auto_start_tournament() CASCADE;
DROP FUNCTION IF EXISTS update_tournament_participants() CASCADE;
DROP FUNCTION IF EXISTS check_max_participants() CASCADE;

-- STEP 3: Verifica che i trigger siano stati rimossi
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE event_object_table = 'tournaments_user';

-- STEP 4: Se necessario, ricrea un trigger CORRETTO per auto-start
-- (Decommenta solo se vuoi la funzionalità di auto-start)
/*
CREATE OR REPLACE FUNCTION auto_start_tournament_on_registration()
RETURNS TRIGGER AS $$
DECLARE
    v_max_participants INTEGER;
    v_current_count INTEGER;
    v_status TEXT;
BEGIN
    -- Qualifica esplicitamente le colonne per evitare ambiguità
    SELECT t.max_participants, t.status INTO v_max_participants, v_status
    FROM tournaments t
    WHERE t.id = NEW.tournament_id;

    -- Se non c'è limite o il torneo non è aperto, esci
    IF v_max_participants IS NULL OR v_status != 'open' THEN
        RETURN NEW;
    END IF;

    -- Conta i partecipanti attivi per QUESTO torneo specifico
    SELECT COUNT(*) INTO v_current_count
    FROM tournaments_user tu
    WHERE tu.tournament_id = NEW.tournament_id 
    AND tu.active = true;

    -- Se ha raggiunto il limite, avvia il torneo
    IF v_current_count >= v_max_participants THEN
        UPDATE tournaments t
        SET status = 'in_progress'
        WHERE t.id = NEW.tournament_id 
        AND t.status = 'open';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_start_tournament
AFTER INSERT OR UPDATE ON tournaments_user
FOR EACH ROW
WHEN (NEW.active = true)
EXECUTE FUNCTION auto_start_tournament_on_registration();
*/

-- STEP 5: Test di inserimento
-- SOSTITUISCI con ID reali
/*
INSERT INTO tournaments_user (tournament_id, user_id, name, active, date)
VALUES (
  'dedb41f4-6e17-4a51-a02b-d9052bd62d08'::uuid,
  (SELECT auth.uid()),
  'Test Player',
  true,
  NOW()
);
*/
