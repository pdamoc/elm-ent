module Client exposing (..)

-- Read more about this program in the official Elm guide:
-- https://guide.elm-lang.org/architecture/effects/http.html

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (Request)
import Json.Decode as Decode
import Dict exposing (Dict)


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { serverData : Req
    }


init : ( Model, Cmd Msg )
init =
    ( Model (Req (Dict.empty) "LOADING" "/none")
    , getServerData
    )



-- UPDATE


type Msg
    = ServerData (Result Http.Error Req)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ServerData (Ok data) ->
            ( Model data, Cmd.none )

        ServerData (Err err) ->
            ( model, Cmd.none )
                |> Debug.log ("error: " ++ (toString err))



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ h2 [] [ text model.serverData.url ]
        , h3 [] [ text model.serverData.method ]
        , div [] [ text (toString model.serverData.headers) ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- HTTP


req : Request Req
req =
    Http.request
        { method = "GET"
        , headers = []
        , url = "http://localhost:8080/json/"
        , body = Http.emptyBody
        , expect = Http.expectJson requestDecoder
        , timeout = Nothing
        , withCredentials = False
        }


getServerData : Cmd Msg
getServerData =
    Http.get "http://localhost:8080/json/" requestDecoder
        |> Http.send ServerData


type alias Req =
    { headers : Dict String String
    , method : String
    , url : String
    }


requestDecoder =
    Decode.map3 Req
        (Decode.field "headers" (Decode.dict Decode.string))
        (Decode.field "method" Decode.string)
        (Decode.field "url" Decode.string)
