-- ========================================
-- SISTEMA COMPLETO TORNEI DI DOPPIO
-- Esegui questo file nel SQL Editor di Supabase
-- ========================================

-- PARTE 1: TABELLE E STRUTTURA BASE
-- ========================================

-- 1. Tabella per le coppie (pairs)
CREATE TABLE IF NOT EXISTS tournament_pairs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  player1_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  player2_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  pair_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(tournament_id, player1_id, player2_id),
  CONSTRAINT one_pair_per_player_per_tournament UNIQUE(tournament_id, player1_id),
  CONSTRAINT one_pair_per_player_per_tournament_2 UNIQUE(tournament_id, player2_id)
);

CREATE INDEX IF NOT EXISTS idx_tournament_pairs_tournament ON tournament_pairs(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_pairs_player1 ON tournament_pairs(player1_id);
CREATE INDEX IF NOT EXISTS idx_tournament_pairs_player2 ON tournament_pairs(player2_id);

-- 2. Tabella per i membri dei gironi (coppie)
CREATE TABLE IF NOT EXISTS tournament_group_pairs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  group_name TEXT NOT NULL,
  pair_id UUID NOT NULL REFERENCES tournament_pairs(id) ON DELETE CASCADE,
  points INTEGER DEFAULT 0,
  matches_played INTEGER DEFAULT 0,
  wins INTEGER DEFAULT 0,
  losses INTEGER DEFAULT 0,
  sets_won INTEGER DEFAULT 0,
  sets_lost INTEGER DEFAULT 0,
  games_won INTEGER DEFAULT 0,
  games_lost INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(tournament_id, group_name, pair_id)
);

CREATE INDEX IF NOT EXISTS idx_tournament_group_pairs_tournament ON tournament_group_pairs(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_group_pairs_pair ON tournament_group_pairs(pair_id);
CREATE INDEX IF NOT EXISTS idx_tournament_group_pairs_group_name ON tournament_group_pairs(group_name);

-- 3. Tabella per le partite di doppio
CREATE TABLE IF NOT EXISTS tournament_doubles_matches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  group_name TEXT,
  pair1_id UUID NOT NULL REFERENCES tournament_pairs(id) ON DELETE CASCADE,
  pair2_id UUID NOT NULL REFERENCES tournament_pairs(id) ON DELETE CASCADE,
  pair1_set1 INTEGER,
  pair2_set1 INTEGER,
  pair1_set2 INTEGER,
  pair2_set2 INTEGER,
  pair1_set3 INTEGER,
  pair2_set3 INTEGER,
  winner_id UUID REFERENCES tournament_pairs(id),
  phase TEXT DEFAULT 'group',
  round TEXT,
  match_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT valid_phase CHECK (phase IN ('group', 'knockout')),
  CONSTRAINT valid_round CHECK (round IS NULL OR round IN ('quarters', 'semis', 'final'))
);

CREATE INDEX IF NOT EXISTS idx_tournament_doubles_matches_tournament ON tournament_doubles_matches(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_doubles_matches_group_name ON tournament_doubles_matches(group_name);
CREATE INDEX IF NOT EXISTS idx_tournament_doubles_matches_pair1 ON tournament_doubles_matches(pair1_id);
CREATE INDEX IF NOT EXISTS idx_tournament_doubles_matches_pair2 ON tournament_doubles_matches(pair2_id);
CREATE INDEX IF NOT EXISTS idx_tournament_doubles_matches_phase ON tournament_doubles_matches(phase);

-- PARTE 2: RLS POLICIES
-- ========================================

ALTER TABLE tournament_pairs ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_group_pairs ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_doubles_matches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view tournament pairs" ON tournament_pairs;
CREATE POLICY "Anyone can view tournament pairs"
ON tournament_pairs FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Players can create pairs for tournaments" ON tournament_pairs;
CREATE POLICY "Players can create pairs for tournaments"
ON tournament_pairs FOR INSERT TO authenticated
WITH CHECK (auth.uid() = player1_id OR auth.uid() = player2_id);

DROP POLICY IF EXISTS "Players can delete their own pairs" ON tournament_pairs;
CREATE POLICY "Players can delete their own pairs"
ON tournament_pairs FOR DELETE TO authenticated
USING (auth.uid() = player1_id OR auth.uid() = player2_id);

DROP POLICY IF EXISTS "Anyone can view group pairs" ON tournament_group_pairs;
CREATE POLICY "Anyone can view group pairs"
ON tournament_group_pairs FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Anyone can view doubles matches" ON tournament_doubles_matches;
CREATE POLICY "Anyone can view doubles matches"
ON tournament_doubles_matches FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Players can update their match results" ON tournament_doubles_matches;
CREATE POLICY "Players can update their match results"
ON tournament_doubles_matches FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM tournament_pairs tp
    WHERE tp.id = tournament_doubles_matches.pair1_id 
    AND (tp.player1_id = auth.uid() OR tp.player2_id = auth.uid())
  ) OR EXISTS (
    SELECT 1 FROM tournament_pairs tp
    WHERE tp.id = tournament_doubles_matches.pair2_id 
    AND (tp.player1_id = auth.uid() OR tp.player2_id = auth.uid())
  )
);

-- PARTE 3: FUNZIONI E TRIGGER
-- ========================================

-- Funzione per calcolare il vincitore
CREATE OR REPLACE FUNCTION calculate_doubles_winner()
RETURNS TRIGGER AS $$
DECLARE
  pair1_sets INTEGER := 0;
  pair2_sets INTEGER := 0;
BEGIN
  IF NEW.pair1_set1 IS NOT NULL AND NEW.pair2_set1 IS NOT NULL THEN
    IF NEW.pair1_set1 > NEW.pair2_set1 THEN pair1_sets := pair1_sets + 1;
    ELSE pair2_sets := pair2_sets + 1; END IF;
  END IF;
  
  IF NEW.pair1_set2 IS NOT NULL AND NEW.pair2_set2 IS NOT NULL THEN
    IF NEW.pair1_set2 > NEW.pair2_set2 THEN pair1_sets := pair1_sets + 1;
    ELSE pair2_sets := pair2_sets + 1; END IF;
  END IF;
  
  IF NEW.pair1_set3 IS NOT NULL AND NEW.pair2_set3 IS NOT NULL THEN
    IF NEW.pair1_set3 > NEW.pair2_set3 THEN pair1_sets := pair1_sets + 1;
    ELSE pair2_sets := pair2_sets + 1; END IF;
  END IF;
  
  IF pair1_sets >= 2 THEN
    NEW.winner_id := NEW.pair1_id;
  ELSIF pair2_sets >= 2 THEN
    NEW.winner_id := NEW.pair2_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_calculate_doubles_winner ON tournament_doubles_matches;
CREATE TRIGGER trigger_calculate_doubles_winner
BEFORE UPDATE ON tournament_doubles_matches
FOR EACH ROW
WHEN (
  OLD.pair1_set1 IS DISTINCT FROM NEW.pair1_set1 OR
  OLD.pair2_set1 IS DISTINCT FROM NEW.pair2_set1 OR
  OLD.pair1_set2 IS DISTINCT FROM NEW.pair1_set2 OR
  OLD.pair2_set2 IS DISTINCT FROM NEW.pair2_set2 OR
  OLD.pair1_set3 IS DISTINCT FROM NEW.pair1_set3 OR
  OLD.pair2_set3 IS DISTINCT FROM NEW.pair2_set3
)
EXECUTE FUNCTION calculate_doubles_winner();

-- Funzione per aggiornare statistiche gruppo
CREATE OR REPLACE FUNCTION update_doubles_group_stats()
RETURNS TRIGGER AS $$
DECLARE
  pair1_sets_won INTEGER := 0;
  pair2_sets_won INTEGER := 0;
  pair1_games_won INTEGER := 0;
  pair2_games_won INTEGER := 0;
BEGIN
  IF NEW.winner_id IS NOT NULL AND OLD.winner_id IS NULL AND NEW.group_name IS NOT NULL THEN
    IF NEW.pair1_set1 > NEW.pair2_set1 THEN pair1_sets_won := pair1_sets_won + 1;
    ELSE pair2_sets_won := pair2_sets_won + 1; END IF;
    
    IF NEW.pair1_set2 > NEW.pair2_set2 THEN pair1_sets_won := pair1_sets_won + 1;
    ELSE pair2_sets_won := pair2_sets_won + 1; END IF;
    
    IF NEW.pair1_set3 IS NOT NULL THEN
      IF NEW.pair1_set3 > NEW.pair2_set3 THEN pair1_sets_won := pair1_sets_won + 1;
      ELSE pair2_sets_won := pair2_sets_won + 1; END IF;
    END IF;
    
    pair1_games_won := COALESCE(NEW.pair1_set1, 0) + COALESCE(NEW.pair1_set2, 0) + COALESCE(NEW.pair1_set3, 0);
    pair2_games_won := COALESCE(NEW.pair2_set1, 0) + COALESCE(NEW.pair2_set2, 0) + COALESCE(NEW.pair2_set3, 0);
    
    UPDATE tournament_group_pairs
    SET 
      matches_played = matches_played + 1,
      wins = wins + CASE WHEN NEW.winner_id = NEW.pair1_id THEN 1 ELSE 0 END,
      losses = losses + CASE WHEN NEW.winner_id = NEW.pair2_id THEN 1 ELSE 0 END,
      points = points + CASE WHEN NEW.winner_id = NEW.pair1_id THEN 3 ELSE 0 END,
      sets_won = sets_won + pair1_sets_won,
      sets_lost = sets_lost + pair2_sets_won,
      games_won = games_won + pair1_games_won,
      games_lost = games_lost + pair2_games_won
    WHERE tournament_id = NEW.tournament_id AND group_name = NEW.group_name AND pair_id = NEW.pair1_id;
    
    UPDATE tournament_group_pairs
    SET 
      matches_played = matches_played + 1,
      wins = wins + CASE WHEN NEW.winner_id = NEW.pair2_id THEN 1 ELSE 0 END,
      losses = losses + CASE WHEN NEW.winner_id = NEW.pair1_id THEN 1 ELSE 0 END,
      points = points + CASE WHEN NEW.winner_id = NEW.pair2_id THEN 3 ELSE 0 END,
      sets_won = sets_won + pair2_sets_won,
      sets_lost = sets_lost + pair1_sets_won,
      games_won = games_won + pair2_games_won,
      games_lost = games_lost + pair1_games_won
    WHERE tournament_id = NEW.tournament_id AND group_name = NEW.group_name AND pair_id = NEW.pair2_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_doubles_group_stats ON tournament_doubles_matches;
CREATE TRIGGER trigger_update_doubles_group_stats
AFTER UPDATE ON tournament_doubles_matches
FOR EACH ROW
WHEN (NEW.winner_id IS NOT NULL AND OLD.winner_id IS DISTINCT FROM NEW.winner_id)
EXECUTE FUNCTION update_doubles_group_stats();

-- PARTE 4: AVVIO AUTOMATICO TORNEO
-- ========================================

CREATE OR REPLACE FUNCTION auto_start_doubles_tournament()
RETURNS TRIGGER AS $$
DECLARE
  pair_count INTEGER;
  max_pairs INTEGER := 16;
  tournament_type TEXT;
  existing_groups_count INTEGER;
  shuffled_pairs UUID[];
  group_ids UUID[];
  pair_idx INTEGER;
  current_group_idx INTEGER;
  group_pairs UUID[];
BEGIN
  SELECT type INTO tournament_type FROM tournaments WHERE id = NEW.tournament_id;
  
  IF tournament_type IS NULL OR (tournament_type NOT ILIKE '%dopp%' AND tournament_type NOT ILIKE '%double%') THEN
    RETURN NEW;
  END IF;
  
  SELECT COUNT(DISTINCT id) INTO pair_count FROM tournament_pairs WHERE tournament_id = NEW.tournament_id;
  
  IF pair_count < max_pairs THEN RETURN NEW; END IF;
  
  SELECT COUNT(*) INTO existing_groups_count FROM tournament_group_pairs WHERE tournament_id = NEW.tournament_id;
  IF existing_groups_count > 0 THEN RETURN NEW; END IF;
  
  UPDATE tournaments SET groups_created = true WHERE id = NEW.tournament_id;
  
  SELECT ARRAY_AGG(id ORDER BY RANDOM()) INTO shuffled_pairs FROM tournament_pairs WHERE tournament_id = NEW.tournament_id;
  
  FOR pair_idx IN 1..16 LOOP
    current_group_idx := ((pair_idx - 1) / 4);
    INSERT INTO tournament_group_pairs (tournament_id, group_name, pair_id, points, matches_played, wins, losses)
    VALUES (
      NEW.tournament_id, 
      CASE current_group_idx
        WHEN 0 THEN 'Girone A'
        WHEN 1 THEN 'Girone B'
        WHEN 2 THEN 'Girone C'
        ELSE 'Girone D'
      END,
      shuffled_pairs[pair_idx], 
      0, 0, 0, 0
    );
  END LOOP;
  
  FOR current_group_idx IN 0..3 LOOP
    SELECT ARRAY_AGG(pair_id) INTO group_pairs 
    FROM tournament_group_pairs 
    WHERE tournament_id = NEW.tournament_id 
    AND group_name = CASE current_group_idx
      WHEN 0 THEN 'Girone A'
      WHEN 1 THEN 'Girone B'
      WHEN 2 THEN 'Girone C'
      ELSE 'Girone D'
    END;
    
    FOR p1_idx IN 1..3 LOOP
      FOR p2_idx IN (p1_idx + 1)..4 LOOP
        INSERT INTO tournament_doubles_matches (tournament_id, group_name, pair1_id, pair2_id, phase)
        VALUES (
          NEW.tournament_id, 
          CASE current_group_idx
            WHEN 0 THEN 'Girone A'
            WHEN 1 THEN 'Girone B'
            WHEN 2 THEN 'Girone C'
            ELSE 'Girone D'
          END,
          group_pairs[p1_idx], 
          group_pairs[p2_idx], 
          'group'
        );
      END LOOP;
    END LOOP;
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_start_doubles ON tournament_pairs;
CREATE TRIGGER trigger_auto_start_doubles
AFTER INSERT ON tournament_pairs
FOR EACH ROW
EXECUTE FUNCTION auto_start_doubles_tournament();

-- PARTE 5: GENERAZIONE SEMIFINALI E FINALE
-- ========================================

CREATE OR REPLACE FUNCTION generate_doubles_knockout()
RETURNS TRIGGER AS $$
DECLARE
  qualified_pairs UUID[];
  quarters_exist INTEGER;
BEGIN
  -- Controlla se tutti i match di gruppo sono completati
  IF NEW.winner_id IS NOT NULL AND OLD.winner_id IS NULL AND NEW.phase = 'group' THEN
    -- Verifica se tutti i match di gruppo sono completati
    IF NOT EXISTS (
      SELECT 1 FROM tournament_doubles_matches
      WHERE tournament_id = NEW.tournament_id AND phase = 'group' AND winner_id IS NULL
    ) THEN
      -- Ottieni i primi 2 di ogni girone
      SELECT ARRAY_AGG(pair_id ORDER BY group_name, points DESC, sets_won DESC, games_won DESC)
      INTO qualified_pairs
      FROM (
        SELECT DISTINCT ON (group_name, pair_id) 
          group_name, pair_id, points, sets_won, games_won,
          ROW_NUMBER() OVER (PARTITION BY group_name ORDER BY points DESC, sets_won DESC, games_won DESC) as position
        FROM tournament_group_pairs
        WHERE tournament_id = NEW.tournament_id
      ) ranked
      WHERE position <= 2;
      
      -- Verifica se i quarti non esistono già
      SELECT COUNT(*) INTO quarters_exist 
      FROM tournament_doubles_matches
      WHERE tournament_id = NEW.tournament_id AND phase = 'knockout' AND round = 'quarters';
      
      IF quarters_exist = 0 AND array_length(qualified_pairs, 1) = 8 THEN
        -- Genera quarti di finale (1°A vs 2°B, 1°B vs 2°A, 1°C vs 2°D, 1°D vs 2°C)
        INSERT INTO tournament_doubles_matches (tournament_id, pair1_id, pair2_id, phase, round)
        VALUES 
          (NEW.tournament_id, qualified_pairs[1], qualified_pairs[4], 'knockout', 'quarters'),
          (NEW.tournament_id, qualified_pairs[3], qualified_pairs[2], 'knockout', 'quarters'),
          (NEW.tournament_id, qualified_pairs[5], qualified_pairs[8], 'knockout', 'quarters'),
          (NEW.tournament_id, qualified_pairs[7], qualified_pairs[6], 'knockout', 'quarters');
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_generate_doubles_knockout ON tournament_doubles_matches;
CREATE TRIGGER trigger_generate_doubles_knockout
AFTER UPDATE ON tournament_doubles_matches
FOR EACH ROW
WHEN (NEW.winner_id IS NOT NULL AND OLD.winner_id IS DISTINCT FROM NEW.winner_id)
EXECUTE FUNCTION generate_doubles_knockout();

CREATE OR REPLACE FUNCTION generate_doubles_semifinals()
RETURNS TRIGGER AS $$
DECLARE
  quarter_winners UUID[];
  semis_exist INTEGER;
BEGIN
  IF NEW.winner_id IS NOT NULL AND OLD.winner_id IS NULL AND NEW.phase = 'knockout' AND NEW.round = 'quarters' THEN
    -- Conta vincitori quarti
    SELECT ARRAY_AGG(winner_id ORDER BY created_at)
    INTO quarter_winners
    FROM tournament_doubles_matches
    WHERE tournament_id = NEW.tournament_id AND phase = 'knockout' AND round = 'quarters' AND winner_id IS NOT NULL;
    
    SELECT COUNT(*) INTO semis_exist 
    FROM tournament_doubles_matches
    WHERE tournament_id = NEW.tournament_id AND phase = 'knockout' AND round = 'semis';
    
    IF array_length(quarter_winners, 1) = 4 AND semis_exist = 0 THEN
      INSERT INTO tournament_doubles_matches (tournament_id, pair1_id, pair2_id, phase, round)
      VALUES 
        (NEW.tournament_id, quarter_winners[1], quarter_winners[2], 'knockout', 'semis'),
        (NEW.tournament_id, quarter_winners[3], quarter_winners[4], 'knockout', 'semis');
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_generate_doubles_semifinals ON tournament_doubles_matches;
CREATE TRIGGER trigger_generate_doubles_semifinals
AFTER UPDATE ON tournament_doubles_matches
FOR EACH ROW
WHEN (NEW.winner_id IS NOT NULL AND OLD.winner_id IS DISTINCT FROM NEW.winner_id)
EXECUTE FUNCTION generate_doubles_semifinals();

CREATE OR REPLACE FUNCTION generate_doubles_final()
RETURNS TRIGGER AS $$
DECLARE
  semi_winners UUID[];
  final_exists INTEGER;
BEGIN
  IF NEW.winner_id IS NOT NULL AND OLD.winner_id IS NULL AND NEW.phase = 'knockout' AND NEW.round = 'semis' THEN
    SELECT ARRAY_AGG(winner_id ORDER BY created_at)
    INTO semi_winners
    FROM tournament_doubles_matches
    WHERE tournament_id = NEW.tournament_id AND phase = 'knockout' AND round = 'semis' AND winner_id IS NOT NULL;
    
    IF array_length(semi_winners, 1) = 2 THEN
      SELECT COUNT(*) INTO final_exists 
      FROM tournament_doubles_matches
      WHERE tournament_id = NEW.tournament_id AND phase = 'knockout' AND round = 'final';
      
      IF final_exists = 0 THEN
        INSERT INTO tournament_doubles_matches (tournament_id, pair1_id, pair2_id, phase, round)
        VALUES (NEW.tournament_id, semi_winners[1], semi_winners[2], 'knockout', 'final');
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_generate_doubles_final ON tournament_doubles_matches;
CREATE TRIGGER trigger_generate_doubles_final
AFTER UPDATE ON tournament_doubles_matches
FOR EACH ROW
WHEN (NEW.winner_id IS NOT NULL AND OLD.winner_id IS DISTINCT FROM NEW.winner_id)
EXECUTE FUNCTION generate_doubles_final();

-- ========================================
-- INSTALLAZIONE COMPLETATA!
-- ========================================
SELECT '✅ Sistema tornei doppio installato con successo!' as status;
