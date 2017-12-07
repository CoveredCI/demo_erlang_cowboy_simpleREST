-module(sample_rest_handler).
-behaviour(cowboy_handler).

-include_lib("kernel/include/logger.hrl").

%% Standard callbacks.
-export([init/2]).
-export([allowed_methods/2]).
-export([content_types_provided/2
        ,content_types_accepted/2]).
-export([resource_exists/2]).
-export([delete_resource/2
        ,delete_completed/2
        ]).

%% Custom callbacks.
-export(['C'/2]).
-export(['R'/2]).

-define(ITEM(Path), <<"/api/v1/item/", (integer_to_binary(Path))/binary>>).


init(Req, Opts) ->
    {cowboy_rest, Req, Opts}.

allowed_methods(Req, State) ->
    Methods = [<<"HEAD">>
              ,<<"GET">>
              ,<<"PUT">>
              ,<<"POST">>
              ,<<"PATCH">>
              ,<<"DELETE">>
              ,<<"OPTIONS">>
              ],
    {Methods, Req, State}.

content_types_provided(Req, State) ->
    CTs = [{<<"application/json">>, 'R'}
          ],
    {CTs, Req, State}.

content_types_accepted(Req, State) ->
    CTs = [{<<"application/x-www-form-urlencoded">>, 'C'}
          ,{<<"application/json">>, 'C'}
          ],
    {CTs, Req, State}.

resource_exists(Req, _State) ->
    case id(Req) of
        undefined -> {true, Req, index};
        ItemId ->
            {sample_crud_store:exists(ItemId), Req, ItemId}
    end.

%% Internals

id(Req) ->
    case cowboy_req:binding(id, Req) of
        undefined -> undefined;
        Id -> binary_to_integer(Id)
    end.

'C'(Req, State) ->
    {ok, ItemBin, Req2} = cowboy_req:read_body(Req),
    ?LOG_DEBUG("received body: ~p", [ItemBin]),
    Item = jsx:decode(ItemBin, [return_maps]),
    ?LOG_DEBUG("decoded JSON: ~s", [jsx:encode(Item)]),
    case cowboy_req:method(Req2) of
        <<"POST">> ->
            ItemId = id(Req2),
            Rep = sample_crud_store:update(ItemId, Item),
            Req3 = cowboy_req:set_resp_body(jsx:encode(Rep), Req2),
            ?LOG_DEBUG("POST ~p", [ItemId]),
            {true, Req3, State};
        <<"PATCH">> ->
            ItemId = id(Req2),
            Rep = sample_crud_store:patch(ItemId, Item),
            Req3 = cowboy_req:set_resp_body(jsx:encode(Rep), Req2),
            ?LOG_DEBUG("PATCH ~p", [ItemId]),
            {true, Req3, State};
        <<"PUT">> ->
            case id(Req2) of
                undefined ->
                    Rep = #{<<"id">> := ItemId} = sample_crud_store:store(Item),
                    Req3 = cowboy_req:set_resp_header(<<"location">>, ?ITEM(ItemId), Req2),
                    Req4 = cowboy_req:set_resp_body(jsx:encode(Rep), Req3),
                    Req5 = cowboy_req:reply(201, Req4),
                    ?LOG_DEBUG("PUT ~p (generated ID)", [ItemId]),
                    {stop, Req5, State};
                ItemId ->
                    Rep = sample_crud_store:put(ItemId, Item),
                    MaybeAlteredRep = case <<>> =:= maps:get(<<"name">>, Rep) of
                                          false -> Rep;
                                          true -> maps:put(<<"name">>, 42, Rep)
                                      end,
                    Req3 = cowboy_req:set_resp_body(jsx:encode(MaybeAlteredRep), Req2),
                    Req4 = cowboy_req:reply(201, Req3),
                    ?LOG_DEBUG("PUT ~p", [ItemId]),
                    {stop, Req4, State}
            end
    end.

'R'(Req, ItemId) ->
    Item = case index =:= ItemId of
               true ->
                   ?LOG_DEBUG("GET"),
                   sample_crud_store:get();
               false ->
                   ?LOG_DEBUG("GET ~p", [ItemId]),
                   sample_crud_store:get(ItemId)
           end,
    {jsx:encode(Item), Req, ItemId}.

delete_resource(Req, State) ->
    Exists = case id(Req) of
                 undefined -> true;
                 ItemId -> sample_crud_store:exists(ItemId)
             end,
    {Exists, Req, State}.

delete_completed(Req0, State) ->
    case id(Req0) of
        undefined ->
            ?LOG_DEBUG("DELETE"),
            sample_crud_store:erase(),
            {true, Req0, State};
        ItemId ->
            ?LOG_DEBUG("DELETE ~p", [ItemId]),
            _Item = sample_crud_store:delete(ItemId),
            {not sample_crud_store:exists(ItemId), Req0, State}
    end.
