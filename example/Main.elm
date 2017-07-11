module Main exposing (..)

import Server exposing (..)
import Task
import Dict


type alias Model =
    Int


main : Server Model
main =
    server 8080 0 handler


res200 url txt =
    { url = url
    , status = { code = 200, message = "" }
    , headers = Dict.empty
    , body = txt
    }


handler : Request -> Model -> ( Model, Response )
handler ({ method, url } as req) model =
    ( model, Task.succeed (res200 url ("Hello " ++ url)) )
