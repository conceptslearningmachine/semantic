{-# LANGUAGE GADTs, TypeOperators, DerivingStrategies #-}
module Semantic.API.Symbols
  ( legacyParseSymbols
  , parseSymbols
  , parseSymbolsBuilder
  ) where

import           Control.Effect
import           Control.Effect.Error
import           Control.Exception
import           Data.Blob
import           Data.ByteString.Builder
import           Data.Location
import           Data.Maybe
import           Data.Term
import           Data.Text (pack)
import           Parsing.Parser
import           Semantic.API.Helpers
import qualified Semantic.API.LegacyTypes as Legacy
import           Semantic.API.Terms (ParseEffects, doParse)
import           Semantic.API.Types hiding (Blob)
import qualified Semantic.API.Types as API
import           Semantic.Task
import           Serializing.Format
import           Tags.Taggable
import           Tags.Tagging

legacyParseSymbols :: (Member Distribute sig, ParseEffects sig m, Traversable t) => t Blob -> m Legacy.ParseTreeSymbolResponse
legacyParseSymbols blobs = Legacy.ParseTreeSymbolResponse <$> distributeFoldMap go blobs
  where
    go :: (Member (Error SomeException) sig, Member Task sig, Carrier sig m, Monad m) => Blob -> m [Legacy.File]
    go blob@Blob{..} = (doParse blob >>= withSomeTerm (renderToSymbols blob)) `catchError` (\(SomeException _) -> pure (pure emptyFile))
      where emptyFile = Legacy.File (pack blobPath) (pack (show blobLanguage)) []

    renderToSymbols :: (IsTaggable f, Applicative m) => Blob -> Term f Location -> m [Legacy.File]
    renderToSymbols blob term = pure $ either mempty (pure . tagsToFile blob) (runTagging blob term)

    tagsToFile :: Blob -> [Tag] -> Legacy.File
    tagsToFile Blob{..} tags = Legacy.File (pack blobPath) (pack (show blobLanguage)) (fmap tagToSymbol tags)

    tagToSymbol :: Tag -> Legacy.Symbol
    tagToSymbol Tag{..}
      = Legacy.Symbol
      { symbolName = name
      , symbolKind = kind
      , symbolLine = fromMaybe mempty line
      , symbolSpan = spanToLegacySpan span
      }

parseSymbolsBuilder :: (Member Distribute sig, ParseEffects sig m, Traversable t) => t Blob -> m Builder
parseSymbolsBuilder blobs
  -- TODO: Switch away from legacy format on CLI too.
  = legacyParseSymbols blobs >>= serialize JSON

parseSymbols :: (Member Distribute sig, ParseEffects sig m, Traversable t) => t API.Blob -> m ParseTreeSymbolResponse
parseSymbols blobs = ParseTreeSymbolResponse <$> distributeFoldMap go (apiBlobToBlob <$> blobs)
  where
    go :: (Member (Error SomeException) sig, Member Task sig, Carrier sig m, Monad m) => Blob -> m [File]
    go blob@Blob{..} = (doParse blob >>= withSomeTerm (renderToSymbols blob)) `catchError` (\(SomeException _) -> pure (pure emptyFile))
      where emptyFile = File (pack blobPath) blobLanguage []

    renderToSymbols :: (IsTaggable f, Applicative m) => Blob -> Term f Location -> m [File]
    renderToSymbols blob term = pure $ either mempty (pure . tagsToFile blob) (runTagging blob term)

    tagsToFile :: Blob -> [Tag] -> File
    tagsToFile Blob{..} tags = File (pack blobPath) blobLanguage (fmap tagToSymbol tags)

    tagToSymbol :: Tag -> Symbol
    tagToSymbol Tag{..}
      = Symbol
      { symbol = name
      , kind = kind
      , line = fromMaybe mempty line
      , span = spanToSpan span
      }