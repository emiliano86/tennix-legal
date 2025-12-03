-- Script per archiviare automaticamente i tornei completati

-- Query da eseguire manualmente o schedulare:
-- SELECT archive_old_completed_tournaments();

-- Se hai pg_cron abilitato su Supabase (Enterprise), puoi schedulare così:
-- SELECT cron.schedule('archive-tournaments', '0 3 * * *', $$SELECT archive_old_completed_tournaments()$$);

-- Altrimenti, esegui manualmente questa query ogni settimana:
SELECT archive_old_completed_tournaments();
