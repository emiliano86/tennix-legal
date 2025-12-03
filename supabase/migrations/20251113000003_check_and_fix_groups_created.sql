-- Verifica lo stato di groups_created per i tornei in corso
SELECT id, name, status, groups_created, 
       (SELECT COUNT(*) FROM tournament_groups WHERE tournament_id = tournaments.id) as num_groups
FROM tournaments
WHERE status = 'in_progress'
ORDER BY created_at DESC;

-- Se ci sono tornei con status='in_progress' ma groups_created=false, correggi:
-- (Commentato per sicurezza - esegui solo se necessario)

-- UPDATE tournaments
-- SET groups_created = true
-- WHERE status = 'in_progress'
--   AND groups_created = false
--   AND EXISTS (
--     SELECT 1 FROM tournament_groups 
--     WHERE tournament_id = tournaments.id
--   );
