module LowLevel
    exposing
        ( listen
        , Settings
        , respond
        , close
        , Server
        , Context
        , request
        )

import Task exposing (Task)
import Json.Encode as Json
import Native.Server
import Http


type Server
    = Server


type alias ContextRecord =
    { request : Json.Value
    , response : Json.Value
    }


type Context
    = Context ContextRecord


request : Context -> Json.Value
request (Context r) =
    r.request


{-| Attempt to listen to a particular port.
-}
listen : Int -> Settings -> Task x Server
listen portNumber settings =
    Native.Server.listen portNumber settings


{-| -}
type alias Settings =
    { onRequest : Context -> Task Never ()
    , onClose : () -> Task Never ()
    }


{-| Respond to the request with the given body
-}
respond : Context -> Http.Response String -> Task x ()
respond ctx res =
    Native.Server.respond ctx res


{-| Close a server's connection
-}
close : Server -> Task x ()
close =
    Native.Server.close
