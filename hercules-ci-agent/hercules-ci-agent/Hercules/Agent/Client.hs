module Hercules.Agent.Client
  ( client
  , tasksClient
  , evalClient
  , metaClient
  , buildClient
  , logsClient
  )
where

import           Protolude
import qualified Servant.Client
import           Servant.Client                 ( ClientM )
import           Servant.Auth.Client            ( )
import           Servant.Client.Generic         ( AsClientT )
import           Hercules.API                   ( HerculesAPI
                                                , ClientAuth
                                                , AddAPIVersion
                                                , servantApi
                                                , eval
                                                , agentBuild
                                                , agentMeta
                                                , tasks
                                                , useApi
                                                )
import           Hercules.API.Agent.Build       ( BuildAPI )
import           Hercules.API.Agent.Evaluate    ( EvalAPI )
import           Hercules.API.Agent.Meta        ( MetaAPI )
import           Hercules.API.Agent.Tasks       ( TasksAPI )
import           Hercules.API.Logs              ( LogsAPI )
import           Servant.API.Generic

client :: HerculesAPI ClientAuth (AsClientT ClientM)
client = fromServant $ Servant.Client.client (servantApi @ClientAuth)

tasksClient :: TasksAPI ClientAuth (AsClientT ClientM)
tasksClient = useApi tasks $ Hercules.Agent.Client.client

evalClient :: EvalAPI ClientAuth (AsClientT ClientM)
evalClient = useApi eval $ Hercules.Agent.Client.client

buildClient :: BuildAPI ClientAuth (AsClientT ClientM)
buildClient = useApi agentBuild $ Hercules.Agent.Client.client

metaClient :: MetaAPI ClientAuth (AsClientT ClientM)
metaClient = useApi agentMeta $ Hercules.Agent.Client.client

logsClient :: LogsAPI () (AsClientT ClientM)
logsClient = fromServant $ Servant.Client.client $ 
  (Proxy @(AddAPIVersion (ToServantApi (LogsAPI ()))))
