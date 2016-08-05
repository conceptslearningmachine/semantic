module Renderer where

import Prologue
import Data.Functor.Both
import Diff
import Source

-- | A function that will render a diff, given the two source blobs.
type Renderer annotation = Both SourceBlob -> Diff Text annotation -> Text

data DiffArguments = DiffArguments { format :: Format, output :: Maybe FilePath, outputPath :: FilePath }
 deriving (Show)

-- | The available types of diff rendering.
data Format = Split | Patch | JSON | Summary
  deriving (Show)
