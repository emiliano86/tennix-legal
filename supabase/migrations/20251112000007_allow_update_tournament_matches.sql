-- Permetti agli utenti di aggiornare i risultati delle partite del torneo

DROP POLICY IF EXISTS "Allow players to update match results" ON tournament_matches;

CREATE POLICY "Allow players to update match results"
ON tournament_matches
FOR UPDATE
USING (
  -- Permetti l'update solo se l'utente è uno dei due giocatori della partita
  auth.uid() = player1_id OR auth.uid() = player2_id
)
WITH CHECK (
  -- Permetti l'update solo se l'utente è uno dei due giocatori della partita
  auth.uid() = player1_id OR auth.uid() = player2_id
);
