-- Modifica il sistema di richieste partite amichevoli
-- Da: richieste dirette a giocatore specifico
-- A: richieste aperte visibili a tutti

-- 1. Rendi il campo to_player_id opzionale (nullable)
ALTER TABLE friendly_matches 
  ALTER COLUMN to_player_id DROP NOT NULL;

-- 2. Aggiungi un campo per indicare se la richiesta è "aperta a tutti"
ALTER TABLE friendly_matches 
  ADD COLUMN IF NOT EXISTS is_open_request BOOLEAN DEFAULT false;

-- 3. Aggiungi commento
COMMENT ON COLUMN friendly_matches.is_open_request IS 
  'True = richiesta aperta a tutti, False = richiesta diretta a giocatore specifico';

-- 4. Aggiorna le RLS policy per permettere a tutti di vedere le richieste aperte
DROP POLICY IF EXISTS "Users can view open match requests" ON friendly_matches;

CREATE POLICY "Users can view open match requests"
ON friendly_matches
FOR SELECT
TO authenticated
USING (
  -- Può vedere le proprie richieste
  from_player_id = auth.uid()
  -- Può vedere le richieste dirette a lui
  OR to_player_id = auth.uid()
  -- Può vedere tutte le richieste aperte in stato pending
  OR (is_open_request = true AND status = 'pending')
  -- Può vedere le partite confermate/completate dove è coinvolto
  OR (status IN ('confirmed', 'completed') AND (from_player_id = auth.uid() OR to_player_id = auth.uid()))
);

-- 5. Policy per accettare richieste aperte
DROP POLICY IF EXISTS "Users can accept open requests" ON friendly_matches;

CREATE POLICY "Users can accept open requests"
ON friendly_matches
FOR UPDATE
TO authenticated
USING (
  -- Può accettare richieste aperte non sue
  (is_open_request = true AND status = 'pending' AND from_player_id != auth.uid())
  -- O aggiornare le proprie richieste/partite
  OR from_player_id = auth.uid()
  OR to_player_id = auth.uid()
)
WITH CHECK (
  -- Può accettare richieste aperte non sue
  (is_open_request = true AND from_player_id != auth.uid())
  -- O aggiornare le proprie richieste/partite
  OR from_player_id = auth.uid()
  OR to_player_id = auth.uid()
);

-- 6. Migrazione dei dati esistenti
-- Le richieste esistenti diventano richieste dirette (is_open_request = false)
UPDATE friendly_matches
SET is_open_request = false
WHERE is_open_request IS NULL;

-- Rendi il campo NOT NULL ora che tutti i record hanno un valore
ALTER TABLE friendly_matches 
  ALTER COLUMN is_open_request SET NOT NULL;

DO $$
BEGIN
  RAISE NOTICE '✅ Sistema richieste aperte configurato!';
  RAISE NOTICE 'Ora i giocatori possono:';
  RAISE NOTICE '  - Creare richieste aperte (visibili a tutti)';
  RAISE NOTICE '  - Creare richieste dirette (a giocatore specifico)';
  RAISE NOTICE '  - Accettare richieste aperte di altri';
END $$;
