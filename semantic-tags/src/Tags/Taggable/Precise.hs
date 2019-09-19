{-# LANGUAGE AllowAmbiguousTypes, DataKinds, DeriveGeneric, DisambiguateRecordFields, FlexibleContexts, FlexibleInstances, MultiParamTypeClasses, NamedFieldPuns, OverloadedStrings, ScopedTypeVariables, TypeApplications, TypeFamilies, TypeOperators, UndecidableInstances #-}
{-# LANGUAGE StandaloneDeriving #-}
module Tags.Taggable.Precise
( Python(..)
, runTagging
) where

import           Control.Effect.Reader
import           Data.Aeson as A
import           Data.Blob
import           Data.Monoid (Ap(..), Endo(..))
import           Data.List.NonEmpty (NonEmpty(..))
import           Data.Location
import           Data.Text (Text)
import           GHC.Generics
import qualified TreeSitter.Python.AST as Python

data Tag = Tag
  { name :: Text
  , kind :: Kind
  , span :: Span
  , context :: [Text]
  , line :: Maybe Text
  , docs :: Maybe Text
  }
  deriving (Eq, Generic, Show)

instance ToJSON Tag


data Kind
  = Function
  | Method
  | Class
  | Module
  | Call
  deriving (Bounded, Enum, Eq, Generic, Show)

instance ToJSON Kind where
  toJSON = toJSON . show
  toEncoding = toEncoding . show


newtype Python a = Python { getPython :: Python.Module a }
  deriving (Eq, Generic, Ord, Show)

type ContextToken = (Text, Maybe Range)

runTagging :: Blob -> Python Location -> [Tag]
runTagging blob
  = ($ [])
  . appEndo
  . run
  . runReader @[ContextToken] []
  . runReader blob
  . tag
  . getPython where

class ToTag t where
  tag
    :: ( Carrier sig m
       , Member (Reader Blob) sig
       , Member (Reader [ContextToken]) sig
       )
    => t
    -> m (Endo [Tag])

instance (ToTagBy strategy t, strategy ~ ToTagInstance t) => ToTag t where
  tag = tag' @strategy


class ToTagBy (strategy :: Strategy) t where
  tag'
    :: ( Carrier sig m
       , Member (Reader Blob) sig
       , Member (Reader [ContextToken]) sig
       )
    => t
    -> m (Endo [Tag])


data Strategy = Generic | Custom

type family ToTagInstance t :: Strategy where
  ToTagInstance Location                             = 'Custom
  ToTagInstance Text                                 = 'Custom
  ToTagInstance [_]                                  = 'Custom
  ToTagInstance (Either _ _)                         = 'Custom
  ToTagInstance (Python.FunctionDefinition Location) = 'Custom
  ToTagInstance _                                    = 'Generic

instance ToTagBy 'Custom Location where
  tag' _ = pure mempty

instance ToTagBy 'Custom Text where
  tag' _ = pure mempty

instance ToTag t => ToTagBy 'Custom [t] where
  tag' = getAp . foldMap (Ap . tag)

instance (ToTag l, ToTag r) => ToTagBy 'Custom (Either l r) where
  tag' = either tag tag

instance ToTagBy 'Custom (Python.FunctionDefinition Location) where
  tag' Python.FunctionDefinition
    { ann
    , name = Python.Identifier { bytes = name }
    , body = Python.Block { extraChildren }
    } = case extraChildren of
      x:_ | isDocComment x -> pure (Endo (Tag name Function (locationSpan ann) [] Nothing Nothing :))
      _                    -> pure (Endo (Tag name Function (locationSpan ann) [] Nothing Nothing :))

isDocComment :: Either (Python.CompoundStatement a) (Python.SimpleStatement a) -> Bool
isDocComment (Right (Python.ExpressionStatementSimpleStatement (Python.ExpressionStatement { extraChildren = Left (Python.PrimaryExpressionExpression Python.StringPrimaryExpression{}) :|_ }))) = True
isDocComment _ = False

instance (Generic t, GToTag (Rep t)) => ToTagBy 'Generic t where
  tag' = gtag . from


class GToTag t where
  gtag
    :: ( Carrier sig m
       , Member (Reader Blob) sig
       , Member (Reader [ContextToken]) sig
       )
    => t a
    -> m (Endo [Tag])


instance GToTag f => GToTag (M1 i c f) where
  gtag = gtag . unM1

instance (GToTag f, GToTag g) => GToTag (f :*: g) where
  gtag (f :*: g) = (<>) <$> gtag f <*> gtag g

instance (GToTag f, GToTag g) => GToTag (f :+: g) where
  gtag (L1 l) = gtag l
  gtag (R1 r) = gtag r

instance ToTag t => GToTag (K1 R t) where
  gtag = tag . unK1

instance GToTag U1 where
  gtag _ = pure mempty