-- ========================================
-- TROVA E RIMUOVI TRIGGER PROBLEMATICI
-- ========================================

-- STEP 1: Trova tutti i trigger sulla tabella tournaments_user
SELECT 
    t.trigger_name,
    t.event_manipulation,
    t.action_timing,
    t.action_statement,
    p.proname as function_name,
    p.prosrc as function_source
FROM information_schema.triggers t
LEFT JOIN pg_proc p ON t.action_statement LIKE '%' || p.proname || '%'
WHERE t.event_object_table = 'tournaments_user';

-- STEP 2: Trova tutte le funzioni che contengono 'max_participants'
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as full_definition
FROM pg_proc p
WHERE p.prosrc ILIKE '%max_participants%'
ORDER BY p.proname;

-- STEP 3: Rimuovi i trigger più comuni che potrebbero causare il problema
-- (Decommentare dopo aver visto i risultati degli STEP 1 e 2)

-- DROP TRIGGER IF EXISTS check_tournament_capacity ON tournaments_user;
-- DROP TRIGGER IF EXISTS validate_tournament_registration ON tournaments_user;
-- DROP TRIGGER IF EXISTS auto_start_tournament_trigger ON tournaments_user;
-- DROP TRIGGER IF EXISTS update_tournament_status ON tournaments_user;

-- STEP 4: Se necessario, rimuovi le funzioni problematiche
-- (Sostituisci 'function_name' con il nome trovato nello STEP 2)

-- DROP FUNCTION IF EXISTS check_tournament_capacity() CASCADE;
-- DROP FUNCTION IF EXISTS validate_tournament_registration() CASCADE;

-- STEP 5: Test di inserimento diretto
-- SOSTITUISCI con ID reali dal tuo database
-- INSERT INTO tournaments_user (tournament_id, user_id, name, active, date)
-- VALUES (
--   'dedb41f4-6e17-4a51-a02b-d9052bd62d08'::uuid,
--   (SELECT auth.uid()),
--   'Test Player',
--   true,
--   NOW()
-- );
