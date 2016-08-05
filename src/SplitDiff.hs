module SplitDiff where

import Data.Record
import Info
import Prologue
import Syntax
import Term (Term)

-- | A patch to only one side of a diff.
data SplitPatch a = SplitInsert a | SplitDelete a | SplitReplace a
  deriving (Show, Eq, Functor)

-- | Get the term from a split patch.
getSplitTerm :: SplitPatch a -> a
getSplitTerm (SplitInsert a) = a
getSplitTerm (SplitDelete a) = a
getSplitTerm (SplitReplace a) = a

-- | Get the range of a SplitDiff.
getRange :: HasField fields Range => SplitDiff leaf (Record fields) -> Range
getRange diff = characterRange $ case runFree diff of
  Free annotated -> headF annotated
  Pure patch -> extract (getSplitTerm patch)

-- | A diff with only one side’s annotations.
type SplitDiff leaf annotation = Free (CofreeF (Syntax leaf) annotation) (SplitPatch (Term leaf annotation))
