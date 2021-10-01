{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DerivingVia #-}

module Hercules.Agent.NixFile.HerculesCIArgs where

import Data.Aeson (ToJSON)
import Hercules.Agent.NixFile.GitSource (GitSource)
import qualified Hercules.Agent.NixFile.GitSource as GitSource
import Hercules.CNix.Expr (ToRawValue, ViaJSON (ViaJSON))
import Protolude

data HerculesCIMeta = HerculesCIMeta
  { apiBaseUrl :: Text
  }
  deriving (Generic, ToJSON)

data HerculesCIArgs = HerculesCIArgs
  { rev :: Text,
    shortRev :: Text,
    ref :: Text,
    branch :: Maybe Text,
    tag :: Maybe Text,
    primaryRepo :: GitSource,
    herculesCI :: HerculesCIMeta
  }
  deriving (Generic, ToJSON)
  deriving (ToRawValue) via (ViaJSON HerculesCIArgs)

fromGitSource :: GitSource -> HerculesCIMeta -> HerculesCIArgs
fromGitSource primary hci =
  HerculesCIArgs
    { rev = GitSource.rev primary,
      shortRev = GitSource.shortRev primary,
      ref = GitSource.ref primary,
      branch = GitSource.branch primary,
      tag = GitSource.tag primary,
      primaryRepo = primary,
      herculesCI = hci
    }
