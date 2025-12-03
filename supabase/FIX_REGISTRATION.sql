-- ========================================
-- FIX RAPIDO REGISTRAZIONE TORNEI
-- ========================================
-- Questo script ripara le policies RLS che potrebbero causare
-- l'errore "column tournament_id does not exist"

-- 1. RIMUOVI TUTTE LE POLICIES ESISTENTI
DROP POLICY IF EXISTS "Users can view tournament registrations" ON tournaments_user;
DROP POLICY IF EXISTS "Users can register for tournaments" ON tournaments_user;
DROP POLICY IF EXISTS "Users can update their registrations" ON tournaments_user;
DROP POLICY IF EXISTS "Users can delete their registrations" ON tournaments_user;
DROP POLICY IF EXISTS "Enable read access for all users" ON tournaments_user;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON tournaments_user;
DROP POLICY IF EXISTS "Enable update for users based on user_id" ON tournaments_user;
DROP POLICY IF EXISTS "Enable delete for users based on user_id" ON tournaments_user;

-- 2. ABILITA RLS SULLA TABELLA
ALTER TABLE tournaments_user ENABLE ROW LEVEL SECURITY;

-- 3. CREA POLICIES SEMPLICI E SICURE

-- Lettura: tutti possono vedere tutte le iscrizioni
CREATE POLICY "Anyone can view tournament registrations"
ON tournaments_user FOR SELECT
USING (true);

-- Inserimento: solo utenti autenticati possono iscriversi
CREATE POLICY "Authenticated users can register"
ON tournaments_user FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Aggiornamento: gli utenti possono modificare solo le proprie iscrizioni
CREATE POLICY "Users can update own registrations"
ON tournaments_user FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Cancellazione: gli utenti possono cancellare solo le proprie iscrizioni
CREATE POLICY "Users can delete own registrations"
ON tournaments_user FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- 4. VERIFICA CHE LA TABELLA ESISTA E ABBIA LA STRUTTURA CORRETTA
-- Se questa query fallisce, la tabella non esiste o è malformata
SELECT 
    column_name, 
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'tournaments_user'
ORDER BY ordinal_position;

-- 5. TEST DI INSERIMENTO (commentato - decommentare per testare)
-- SOSTITUISCI i valori con ID reali dal tuo database
-- INSERT INTO tournaments_user (tournament_id, user_id, name, active, date)
-- VALUES (
--   'xxx-xxx-xxx-xxx'::uuid,  -- ID torneo reale
--   'yyy-yyy-yyy-yyy'::uuid,  -- ID utente reale
--   'Test Player',
--   true,
--   NOW()
-- );
