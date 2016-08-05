module Algorithm where

import Control.Monad.Free.Church
import Prologue

-- | A single step in a diffing algorithm.
--
-- 'term' is the type of terms.
-- 'diff' is the type of diffs.
-- 'f' represents the continuation after diffing. Often 'Algorithm'.
data AlgorithmF term diff f
  -- | Recursively diff two terms and pass the result to the continuation.
  = Recursive term term (diff -> f)
  -- | Diff two lists by each element’s position, and pass the resulting list of diffs to the continuation.
  | ByIndex [term] [term] ([diff] -> f)
  -- | Diff two lists by each element’s similarity and pass the resulting list of diffs to the continuation.
  | BySimilarity [term] [term] ([diff] -> f)
  deriving Functor

-- | The free monad for 'AlgorithmF'. This enables us to construct diff values using do-notation. We use the Church-encoded free monad 'F' for efficiency.
type Algorithm term diff = F (AlgorithmF term diff)


-- DSL

-- | Constructs a 'Recursive' diff of two terms.
recursively :: term -> term -> Algorithm term diff diff
recursively a b = wrap (Recursive a b pure)

-- | Constructs a 'ByIndex' diff of two lists of terms.
byIndex :: [term] -> [term] -> Algorithm term diff [diff]
byIndex a b = wrap (ByIndex a b pure)

-- | Constructs a 'BySimilarity' diff of two lists of terms.
bySimilarity :: [term] -> [term] -> Algorithm term diff [diff]
bySimilarity a b = wrap (BySimilarity a b pure)
