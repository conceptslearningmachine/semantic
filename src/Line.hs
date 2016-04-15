{-# LANGUAGE FlexibleInstances #-}
module Line where

import Control.Applicative
import Data.Coalescent

-- | A line of items or an empty line.
data Line a = Line [a] | Closed [a]
  deriving (Eq, Foldable, Functor, Show, Traversable)

-- | Construct a single-element Line with a predicate determining whether the line is open.
pureBy :: (a -> Bool) -> a -> Line a
pureBy predicate a | predicate a = Line [ a ]
                   | otherwise = Closed [ a ]

unLine :: Line a -> [a]
unLine (Line as) = as
unLine (Closed as) = as

-- | Is the given line empty?
isEmpty :: Line a -> Bool
isEmpty = null . unLine

-- | Is the given line open?
isOpen :: Line a -> Bool
isOpen (Line _) = True
isOpen _ = False

-- | The increment the given line implies for line numbering.
lineIncrement :: Num n => Line a -> n
lineIncrement line | isEmpty line = 0
                   | otherwise = 1

-- | Transform the line by applying a function to a list of all the items in the
-- | line.
wrapLineContents :: ([a] -> b) -> Line a -> Line b
wrapLineContents transform line = lineMap (if isEmpty line then const [] else pure . transform) line

-- | Map the elements of a line, preserving closed lines.
lineMap :: ([a] -> [b]) -> Line a -> Line b
lineMap f (Line ls) = Line (f ls)
lineMap f (Closed cs) = Closed (f cs)

instance Applicative Line where
  pure = Line . pure
  as <*> bs | isOpen as && isOpen bs = Line (unLine as <*> unLine bs)
            | otherwise = Closed (unLine as <*> unLine bs)

instance Monoid (Line a) where
  mempty = Line []
  mappend xs ys = lineMap (mappend (unLine xs)) ys

instance Coalescent (Line a) where
  coalesce a b | isOpen a = pure (a `mappend` b)
               | otherwise = pure a <|> pure b
