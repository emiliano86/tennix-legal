-- ========================================
-- FIX PER "column reference is ambiguous"
-- ========================================
-- Questo errore si verifica quando una policy RLS o un trigger
-- fa riferimento a colonne senza qualificarle con il nome della tabella

-- STEP 1: Identifica le policy problematiche
-- Esegui questa query per vedere tutte le policy sulla tabella tournaments_user
SELECT 
    schemaname,
    tablename, 
    policyname,
    permissive,
    cmd,
    qual as "using_clause",
    with_check as "with_check_clause"
FROM pg_policies
WHERE tablename = 'tournaments_user';

-- STEP 2: Rimuovi le policy esistenti che potrebbero avere riferimenti ambigui
DROP POLICY IF EXISTS "Users can view tournament registrations" ON tournaments_user;
DROP POLICY IF EXISTS "Users can register for tournaments" ON tournaments_user;
DROP POLICY IF EXISTS "Users can update their registrations" ON tournaments_user;
DROP POLICY IF EXISTS "Users can delete their registrations" ON tournaments_user;
DROP POLICY IF EXISTS "Enable read access for all users" ON tournaments_user;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON tournaments_user;
DROP POLICY IF EXISTS "Enable update for users based on user_id" ON tournaments_user;
DROP POLICY IF EXISTS "Enable delete for users based on user_id" ON tournaments_user;
DROP POLICY IF EXISTS "Anyone can view tournament registrations" ON tournaments_user;
DROP POLICY IF EXISTS "Authenticated users can register" ON tournaments_user;
DROP POLICY IF EXISTS "Users can update own registrations" ON tournaments_user;
DROP POLICY IF EXISTS "Users can delete own registrations" ON tournaments_user;

-- STEP 3: Verifica e rimuovi eventuali trigger problematici
-- Prima vediamo quali trigger esistono
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tournaments_user';

-- Se ci sono trigger che causano problemi, possono essere rimossi con:
-- DROP TRIGGER IF EXISTS nome_trigger ON tournaments_user;

-- STEP 4: Ricrea policy RLS SEMPLICI senza riferimenti a colonne di altre tabelle
ALTER TABLE tournaments_user ENABLE ROW LEVEL SECURITY;

-- Policy per SELECT - tutti possono leggere
CREATE POLICY "select_all" 
ON tournaments_user 
FOR SELECT 
USING (true);

-- Policy per INSERT - solo l'utente autenticato può inserire con il proprio user_id
CREATE POLICY "insert_own" 
ON tournaments_user 
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Policy per UPDATE - solo l'utente autenticato può aggiornare i propri record
CREATE POLICY "update_own" 
ON tournaments_user 
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy per DELETE - solo l'utente autenticato può cancellare i propri record
CREATE POLICY "delete_own" 
ON tournaments_user 
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- STEP 5: Verifica che le policy siano state create correttamente
SELECT 
    policyname,
    cmd,
    qual as "using_clause"
FROM pg_policies
WHERE tablename = 'tournaments_user'
ORDER BY policyname;

-- NOTA IMPORTANTE:
-- Se il problema persiste dopo questo fix, potrebbe essere causato da:
-- 1. Un trigger sulla tabella tournaments_user
-- 2. Una function/trigger sulla tabella tournaments che viene richiamata
-- 3. Una policy RLS su un'altra tabella correlata (es. tournaments)
--
-- In quel caso, esegui anche:
-- SELECT proname, prosrc FROM pg_proc WHERE prosrc ILIKE '%max_participants%';
-- per trovare tutte le funzioni che usano max_participants
