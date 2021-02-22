{-# LANGUAGE FunctionalDependencies #-}
module Melude.Result where

import Prelude hiding (fail, error)
import GHC.Stack (CallStack, prettyCallStack)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Sequence.NonEmpty (NESeq)
import qualified Data.Sequence.NonEmpty as NonEmptySeq
import Data.Functor ((<&>))
import Data.Function ((&))
import Data.Foldable (Foldable(fold))
import Data.Sequence (Seq)
import qualified Data.Sequence as Seq
import Melude.NonEmptySeq (NESeq((:<||)))

type NonEmptySeq a = NESeq a

data Failure e = Failure !(Maybe CallStack) !e
  deriving Functor

data Result e a
  = Failures !(NonEmptySeq (Failure e))
  | Success a
  deriving Functor

-- pattern Fail :: e -> CallStack -> Result e a
-- pattern Fail e cs = Failures ((Failure (Just cs) e) :<|| Seq.Empty)

fromErrorWithCallStack :: e -> CallStack -> Result e a
fromErrorWithCallStack error stack = error & Failure (Just stack) & NonEmptySeq.singleton & Failures

fromError :: e -> Result e a
fromError error = error & Failure Nothing & NonEmptySeq.singleton & Failures

toErrors :: Result e a -> Seq e
toErrors (Failures failures) = failures <&> failureToError & NonEmptySeq.toSeq
toErrors _ = Seq.empty

failureToError :: Failure e -> e
failureToError (Failure _ e) = e

failureToText :: Show e => Failure e -> Text
failureToText (Failure (Just stack) e) = Text.pack (show e) <> "\n" <> Text.pack (prettyCallStack stack)
failureToText (Failure Nothing e) = Text.pack (show e)

failuresToText :: Show e => NonEmptySeq (Failure e) -> Text
failuresToText failures = failures <&> failureToText & NonEmptySeq.intersperse "\n" & fold

instance (Show e, Show a) => Show (Result e a) where
  show (Failures failures) = "Failures:\n" <> failuresToText failures & Text.unpack
  show (Success a) = "Success(" <> show a <> ")"

instance Applicative (Result e) where
  pure = Success

  (<*>) (Failures leftErrors) (Failures rightErrors) = Failures (leftErrors <> rightErrors)
  (<*>) (Failures failures) _ = Failures failures
  (<*>) _ (Failures failures) = Failures failures
  (<*>) (Success f) (Success a) = Success (f a)

instance Monad (Result e) where
  (>>=) (Failures failures) _ = Failures failures
  (>>=) (Success a) f = f a


