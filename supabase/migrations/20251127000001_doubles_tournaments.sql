-- Sistema completo per tornei di doppio
-- 16 coppie (32 giocatori totali)
-- 4 gironi da 4 coppie
-- Punteggio: 2 set a 6 game + tie-break a 10 punti al 3° set

-- 1. Tabella per le coppie (pairs)
CREATE TABLE IF NOT EXISTS tournament_pairs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  player1_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  player2_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  pair_name TEXT, -- Nome della coppia (opzionale)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(tournament_id, player1_id, player2_id),
  -- Assicura che lo stesso giocatore non sia in più coppie dello stesso torneo
  CONSTRAINT one_pair_per_player_per_tournament UNIQUE(tournament_id, player1_id),
  CONSTRAINT one_pair_per_player_per_tournament_2 UNIQUE(tournament_id, player2_id)
);

-- Index per performance
CREATE INDEX idx_tournament_pairs_tournament ON tournament_pairs(tournament_id);
CREATE INDEX idx_tournament_pairs_player1 ON tournament_pairs(player1_id);
CREATE INDEX idx_tournament_pairs_player2 ON tournament_pairs(player2_id);

-- 2. Tabella per i membri dei gironi (coppie)
CREATE TABLE IF NOT EXISTS tournament_group_pairs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  group_id UUID NOT NULL REFERENCES tournament_groups(id) ON DELETE CASCADE,
  pair_id UUID NOT NULL REFERENCES tournament_pairs(id) ON DELETE CASCADE,
  points INTEGER DEFAULT 0,
  matches_played INTEGER DEFAULT 0,
  matches_won INTEGER DEFAULT 0,
  matches_lost INTEGER DEFAULT 0,
  sets_won INTEGER DEFAULT 0,
  sets_lost INTEGER DEFAULT 0,
  games_won INTEGER DEFAULT 0,
  games_lost INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(group_id, pair_id)
);

CREATE INDEX idx_tournament_group_pairs_group ON tournament_group_pairs(group_id);
CREATE INDEX idx_tournament_group_pairs_pair ON tournament_group_pairs(pair_id);

-- 3. Tabella per le partite di doppio
CREATE TABLE IF NOT EXISTS tournament_doubles_matches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  group_id UUID REFERENCES tournament_groups(id) ON DELETE CASCADE,
  pair1_id UUID NOT NULL REFERENCES tournament_pairs(id) ON DELETE CASCADE,
  pair2_id UUID NOT NULL REFERENCES tournament_pairs(id) ON DELETE CASCADE,
  
  -- Punteggio dettagliato per set
  set1_pair1_score INTEGER,
  set1_pair2_score INTEGER,
  set2_pair1_score INTEGER,
  set2_pair2_score INTEGER,
  set3_pair1_score INTEGER, -- Tie-break a 10 punti
  set3_pair2_score INTEGER,
  
  winner_pair_id UUID REFERENCES tournament_pairs(id),
  status TEXT DEFAULT 'scheduled', -- scheduled, in_progress, completed, cancelled
  phase TEXT DEFAULT 'group', -- group, knockout
  round TEXT, -- quarter_final, semi_final, final
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  
  CONSTRAINT valid_status CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
  CONSTRAINT valid_phase CHECK (phase IN ('group', 'knockout')),
  CONSTRAINT valid_round CHECK (round IS NULL OR round IN ('quarter_final', 'semi_final', 'final', 'third_place'))
);

CREATE INDEX idx_tournament_doubles_matches_tournament ON tournament_doubles_matches(tournament_id);
CREATE INDEX idx_tournament_doubles_matches_group ON tournament_doubles_matches(group_id);
CREATE INDEX idx_tournament_doubles_matches_pair1 ON tournament_doubles_matches(pair1_id);
CREATE INDEX idx_tournament_doubles_matches_pair2 ON tournament_doubles_matches(pair2_id);
CREATE INDEX idx_tournament_doubles_matches_status ON tournament_doubles_matches(status);
CREATE INDEX idx_tournament_doubles_matches_phase ON tournament_doubles_matches(phase);

-- 4. RLS Policies

-- tournament_pairs
ALTER TABLE tournament_pairs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view tournament pairs"
ON tournament_pairs FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Players can create pairs for tournaments"
ON tournament_pairs FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = player1_id OR auth.uid() = player2_id);

CREATE POLICY "Players can delete their own pairs"
ON tournament_pairs FOR DELETE
TO authenticated
USING (auth.uid() = player1_id OR auth.uid() = player2_id);

-- tournament_group_pairs
ALTER TABLE tournament_group_pairs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view group pairs"
ON tournament_group_pairs FOR SELECT
TO authenticated
USING (true);

-- tournament_doubles_matches
ALTER TABLE tournament_doubles_matches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view doubles matches"
ON tournament_doubles_matches FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Players can update their match results"
ON tournament_doubles_matches FOR UPDATE
TO authenticated
USING (
  -- Permetti l'update se l'utente è in una delle due coppie
  EXISTS (
    SELECT 1 FROM tournament_pairs
    WHERE id = pair1_id
    AND (player1_id = auth.uid() OR player2_id = auth.uid())
  )
  OR
  EXISTS (
    SELECT 1 FROM tournament_pairs
    WHERE id = pair2_id
    AND (player1_id = auth.uid() OR player2_id = auth.uid())
  )
);

-- 5. Funzione per calcolare il vincitore in base ai set
CREATE OR REPLACE FUNCTION calculate_doubles_winner()
RETURNS TRIGGER AS $$
DECLARE
  pair1_sets INTEGER := 0;
  pair2_sets INTEGER := 0;
BEGIN
  -- Conta i set vinti da ogni coppia
  IF NEW.set1_pair1_score IS NOT NULL AND NEW.set1_pair2_score IS NOT NULL THEN
    IF NEW.set1_pair1_score > NEW.set1_pair2_score THEN
      pair1_sets := pair1_sets + 1;
    ELSE
      pair2_sets := pair2_sets + 1;
    END IF;
  END IF;
  
  IF NEW.set2_pair1_score IS NOT NULL AND NEW.set2_pair2_score IS NOT NULL THEN
    IF NEW.set2_pair1_score > NEW.set2_pair2_score THEN
      pair1_sets := pair1_sets + 1;
    ELSE
      pair2_sets := pair2_sets + 1;
    END IF;
  END IF;
  
  IF NEW.set3_pair1_score IS NOT NULL AND NEW.set3_pair2_score IS NOT NULL THEN
    IF NEW.set3_pair1_score > NEW.set3_pair2_score THEN
      pair1_sets := pair1_sets + 1;
    ELSE
      pair2_sets := pair2_sets + 1;
    END IF;
  END IF;
  
  -- Determina il vincitore (chi vince 2 set)
  IF pair1_sets >= 2 THEN
    NEW.winner_pair_id := NEW.pair1_id;
    NEW.status := 'completed';
    NEW.completed_at := NOW();
  ELSIF pair2_sets >= 2 THEN
    NEW.winner_pair_id := NEW.pair2_id;
    NEW.status := 'completed';
    NEW.completed_at := NOW();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calculate_doubles_winner
BEFORE UPDATE ON tournament_doubles_matches
FOR EACH ROW
WHEN (
  OLD.set1_pair1_score IS DISTINCT FROM NEW.set1_pair1_score OR
  OLD.set1_pair2_score IS DISTINCT FROM NEW.set1_pair2_score OR
  OLD.set2_pair1_score IS DISTINCT FROM NEW.set2_pair1_score OR
  OLD.set2_pair2_score IS DISTINCT FROM NEW.set2_pair2_score OR
  OLD.set3_pair1_score IS DISTINCT FROM NEW.set3_pair1_score OR
  OLD.set3_pair2_score IS DISTINCT FROM NEW.set3_pair2_score
)
EXECUTE FUNCTION calculate_doubles_winner();

-- 6. Funzione per aggiornare statistiche gruppo dopo partita completata
CREATE OR REPLACE FUNCTION update_doubles_group_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Aggiorna solo se la partita è stata completata
  IF NEW.status = 'completed' AND OLD.status != 'completed' AND NEW.group_id IS NOT NULL THEN
    -- Calcola set e game vinti/persi
    DECLARE
      pair1_sets_won INTEGER := 0;
      pair2_sets_won INTEGER := 0;
      pair1_games_won INTEGER := 0;
      pair2_games_won INTEGER := 0;
    BEGIN
      -- Conta set vinti
      IF NEW.set1_pair1_score > NEW.set1_pair2_score THEN pair1_sets_won := pair1_sets_won + 1;
      ELSE pair2_sets_won := pair2_sets_won + 1; END IF;
      
      IF NEW.set2_pair1_score > NEW.set2_pair2_score THEN pair1_sets_won := pair1_sets_won + 1;
      ELSE pair2_sets_won := pair2_sets_won + 1; END IF;
      
      IF NEW.set3_pair1_score IS NOT NULL THEN
        IF NEW.set3_pair1_score > NEW.set3_pair2_score THEN pair1_sets_won := pair1_sets_won + 1;
        ELSE pair2_sets_won := pair2_sets_won + 1; END IF;
      END IF;
      
      -- Somma tutti i game
      pair1_games_won := COALESCE(NEW.set1_pair1_score, 0) + COALESCE(NEW.set2_pair1_score, 0) + COALESCE(NEW.set3_pair1_score, 0);
      pair2_games_won := COALESCE(NEW.set1_pair2_score, 0) + COALESCE(NEW.set2_pair2_score, 0) + COALESCE(NEW.set3_pair2_score, 0);
      
      -- Aggiorna statistiche coppia 1
      UPDATE tournament_group_pairs
      SET 
        matches_played = matches_played + 1,
        matches_won = matches_won + CASE WHEN NEW.winner_pair_id = NEW.pair1_id THEN 1 ELSE 0 END,
        matches_lost = matches_lost + CASE WHEN NEW.winner_pair_id = NEW.pair2_id THEN 1 ELSE 0 END,
        points = points + CASE WHEN NEW.winner_pair_id = NEW.pair1_id THEN 10 ELSE 0 END,
        sets_won = sets_won + pair1_sets_won,
        sets_lost = sets_lost + pair2_sets_won,
        games_won = games_won + pair1_games_won,
        games_lost = games_lost + pair2_games_won
      WHERE group_id = NEW.group_id AND pair_id = NEW.pair1_id;
      
      -- Aggiorna statistiche coppia 2
      UPDATE tournament_group_pairs
      SET 
        matches_played = matches_played + 1,
        matches_won = matches_won + CASE WHEN NEW.winner_pair_id = NEW.pair2_id THEN 1 ELSE 0 END,
        matches_lost = matches_lost + CASE WHEN NEW.winner_pair_id = NEW.pair1_id THEN 1 ELSE 0 END,
        points = points + CASE WHEN NEW.winner_pair_id = NEW.pair2_id THEN 10 ELSE 0 END,
        sets_won = sets_won + pair2_sets_won,
        sets_lost = sets_lost + pair1_sets_won,
        games_won = games_won + pair2_games_won,
        games_lost = games_lost + pair1_games_won
      WHERE group_id = NEW.group_id AND pair_id = NEW.pair2_id;
    END;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_doubles_group_stats
AFTER UPDATE ON tournament_doubles_matches
FOR EACH ROW
WHEN (NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed')
EXECUTE FUNCTION update_doubles_group_stats();

DO $$
BEGIN
  RAISE NOTICE '✅ Sistema tornei doppio creato con successo!';
  RAISE NOTICE '📋 Tabelle create:';
  RAISE NOTICE '  - tournament_pairs (coppie)';
  RAISE NOTICE '  - tournament_group_pairs (coppie nei gironi)';
  RAISE NOTICE '  - tournament_doubles_matches (partite di doppio)';
  RAISE NOTICE '📊 Formato punteggio: 2 set a 6 game + tie-break a 10 punti';
  RAISE NOTICE '🎾 Configurazione: 16 coppie, 4 gironi da 4 coppie ciascuno';
END $$;
