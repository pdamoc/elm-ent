effect module Server
    where { command = MyCmd, subscription = MySub }
    exposing
        ( Request
        , Method
        , Response
        , Server
        , server
        )

{-|


# Types

@docs Request, Method, Response, Server


# methods

@docs server, fromJson

-}

import Dict
import Process
import Task exposing (Task)
import LowLevel
import Dict exposing (Dict)
import Http
import Json.Decode as Decode


{-| Request record
-}
type alias Request =
    { headers : Dict String String
    , method : Method
    , url : String
    }


{-| Method Type
-}
type Method
    = GET
    | POST
    | PUT
    | DELETE


{-| Type alias for a `Http.Response String` producing Task
-}
type alias Response =
    Task Never (Http.Response String)


methodDecoder : Decode.Decoder Method
methodDecoder =
    (Decode.field "method" Decode.string)
        |> Decode.andThen
            (\method ->
                case method of
                    "GET" ->
                        Decode.succeed GET

                    "POST" ->
                        Decode.succeed POST

                    "PUT" ->
                        Decode.succeed PUT

                    "DELETE" ->
                        Decode.succeed DELETE

                    _ ->
                        Decode.fail ("Unsupported method: " ++ method)
            )


requestDecoder : Decode.Decoder Request
requestDecoder =
    Decode.map3 Request
        (Decode.field "headers" (Decode.dict Decode.string))
        methodDecoder
        (Decode.field "url" Decode.string)


toHandlerRequest : LowLevel.Context -> Request
toHandlerRequest ctx =
    Decode.decodeValue requestDecoder (LowLevel.request ctx)
        |> Result.withDefault (Request Dict.empty DELETE "/thisShouldNeverHappen")


type InternalMsg model
    = ServerRequest LowLevel.Context
    | ServerResponse LowLevel.Context model (Http.Response String)


update : (Request -> model -> ( model, Response )) -> InternalMsg model -> model -> ( model, Cmd (InternalMsg model) )
update handler msg model =
    case msg of
        ServerRequest req ->
            let
                ( newModel, responseTask ) =
                    handler (toHandlerRequest req) model
            in
                ( model, Task.perform (ServerResponse req newModel) responseTask )

        ServerResponse req newModel res ->
            ( newModel, respond req res )


type alias Server model =
    Program Never model (InternalMsg model)


server : Int -> model -> (Request -> model -> ( model, Response )) -> Server model
server portNumber init handler =
    Platform.program
        { init = ( init, Cmd.none )
        , update = update handler
        , subscriptions = always (listen portNumber ServerRequest)
        }



-- COMMANDS


type MyCmd msg
    = Respond LowLevel.Context (Http.Response String)


respond : LowLevel.Context -> Http.Response String -> Cmd msg
respond request message =
    command (Respond request message)


cmdMap : (a -> b) -> MyCmd a -> MyCmd b
cmdMap _ (Respond request msg) =
    Respond request msg



-- SUBSCRIPTIONS


type MySub msg
    = Listen Int (LowLevel.Context -> msg)


{-| Subscribe to all requests that come in on a port
-}
listen : Int -> (LowLevel.Context -> msg) -> Sub msg
listen portNumber tagger =
    subscription (Listen portNumber tagger)


subMap : (a -> b) -> MySub a -> MySub b
subMap func sub =
    case sub of
        Listen portNumber tagger ->
            Listen portNumber (tagger >> func)



-- MANAGER


type alias State msg =
    { servers : ServerDict
    , subs : SubsDict msg
    }


type alias ServerDict =
    Dict.Dict Int InternalServer


type alias SubsDict msg =
    Dict.Dict Int (List (LowLevel.Context -> msg))


type InternalServer
    = Opening Process.Id
    | Listening LowLevel.Server


init : Task Never (State msg)
init =
    Task.succeed (State Dict.empty Dict.empty)



-- HANDLE APP MESSAGES


(&>) : Task x a -> Task x b -> Task x b
(&>) t1 t2 =
    t1
        |> Task.andThen (\_ -> t2)


onEffects :
    Platform.Router msg Msg
    -> List (MyCmd msg)
    -> List (MySub msg)
    -> State msg
    -> Task Never (State msg)
onEffects router cmds subs state =
    let
        newSubs =
            buildSubDict subs Dict.empty

        cleanup _ =
            let
                newEntries =
                    (Dict.map (\k v -> []) newSubs)

                leftStep portNumber _ getNewServers =
                    getNewServers
                        |> Task.andThen
                            (\newServers ->
                                attemptOpen router portNumber
                                    |> Task.andThen
                                        (\pid ->
                                            Task.succeed (Dict.insert portNumber (Opening pid) newServers)
                                        )
                            )

                bothStep portNumber _ server getNewServers =
                    Task.map (Dict.insert portNumber server) getNewServers

                rightStep portNumber server getNewServers =
                    close server &> getNewServers
            in
                Dict.merge leftStep bothStep rightStep newEntries state.servers (Task.succeed Dict.empty)
                    |> Task.andThen (\newServers -> Task.succeed (State newServers newSubs))
    in
        sendReplies cmds
            |> Task.andThen cleanup


sendReplies : List (MyCmd msg) -> Task x ()
sendReplies cmds =
    case cmds of
        [] ->
            Task.succeed ()

        (Respond request msg) :: rest ->
            LowLevel.respond request msg
                &> sendReplies rest


buildSubDict : List (MySub msg) -> SubsDict msg -> SubsDict msg
buildSubDict subs dict =
    case subs of
        [] ->
            dict

        (Listen portNumber tagger) :: rest ->
            buildSubDict rest (Dict.update portNumber (add tagger) dict)


add : a -> Maybe (List a) -> Maybe (List a)
add value maybeList =
    case maybeList of
        Nothing ->
            Just [ value ]

        Just list ->
            Just (value :: list)



-- HANDLE SELF MESSAGES


type Msg
    = RequestMsg Int LowLevel.Context
    | Die Int
    | Open Int LowLevel.Server


onSelfMsg : Platform.Router msg Msg -> Msg -> State msg -> Task Never (State msg)
onSelfMsg router selfMsg state =
    case selfMsg of
        RequestMsg portNumber request ->
            let
                requests =
                    Dict.get portNumber state.subs
                        |> Maybe.withDefault []
                        |> List.map (\tagger -> Platform.sendToApp router (tagger request))
            in
                Task.sequence requests
                    &> Task.succeed state

        Die portNumber ->
            case Dict.get portNumber state.servers of
                Nothing ->
                    Task.succeed state

                Just _ ->
                    attemptOpen router portNumber
                        |> Task.andThen
                            (\pid -> Task.succeed (updateServer portNumber (Opening pid) state))

        Open portNumber server ->
            Task.succeed (updateServer portNumber (Listening server) state)


removeServer : Int -> State msg -> State msg
removeServer portNumber state =
    { state | servers = Dict.remove portNumber state.servers }


updateServer : Int -> InternalServer -> State msg -> State msg
updateServer portNumber server state =
    { state | servers = Dict.insert portNumber server state.servers }


attemptOpen : Platform.Router msg Msg -> Int -> Task x Process.Id
attemptOpen router portNumber =
    open router portNumber
        |> Task.andThen (Platform.sendToSelf router << Open portNumber)
        |> Process.spawn


open : Platform.Router msg Msg -> Int -> Task x LowLevel.Server
open router portNumber =
    LowLevel.listen portNumber
        { onRequest = \request -> Platform.sendToSelf router (RequestMsg portNumber request)
        , onClose = \_ -> Platform.sendToSelf router (Die portNumber)
        }


close : InternalServer -> Task x ()
close server =
    case server of
        Opening pid ->
            Process.kill pid

        Listening server ->
            LowLevel.close server
