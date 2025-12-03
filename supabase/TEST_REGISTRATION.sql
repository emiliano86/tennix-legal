-- ========================================
-- TEST REGISTRAZIONE TORNEO
-- ========================================
-- Esegui questo nel SQL Editor per verificare se le tabelle esistono

-- 1. Verifica struttura tabella tournaments
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'tournaments'
ORDER BY ordinal_position;

-- 2. Verifica struttura tabella tournaments_user
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'tournaments_user'
ORDER BY ordinal_position;

-- 3. Test query simile a quella dell'app
SELECT id, max_participants, status
FROM tournaments
WHERE status = 'open'
LIMIT 1;

-- 4. Conta partecipanti per un torneo (usa l'ID dal risultato sopra)
-- SOSTITUISCI 'xxx-xxx-xxx' con un ID reale dalla query 3
-- SELECT COUNT(*) 
-- FROM tournaments_user 
-- WHERE tournament_id = 'xxx-xxx-xxx' 
-- AND active = true;
