-- ========================================
-- VERIFICA RLS POLICIES E TRIGGERS
-- ========================================

-- 1. Mostra tutte le policies sulla tabella tournaments_user
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'tournaments_user';

-- 2. Mostra tutti i triggers sulla tabella tournaments_user
SELECT trigger_name, event_manipulation, event_object_table, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tournaments_user';

-- 3. Mostra tutti i triggers sulla tabella tournaments
SELECT trigger_name, event_manipulation, event_object_table, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tournaments';

-- 4. Verifica se esistono le nuove tabelle per i doppi
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('tournament_pairs', 'tournament_group_pairs', 'tournament_doubles_matches');
