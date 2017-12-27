%% -*- coding: utf-8 -*-

%% @module Work provider for workers
-module(sample_crud_store).
-behaviour(gen_server).

-include("sample.hrl").

%% API
-export([start_link/0]).
-export([s/1, c/2, l/0, r/1, u/2, p/2, e/0, d/1
        ,put/2, store/1, get/0, get/1, update/2, patch/2, erase/0, delete/1
        ,exists/1
        ,id/0
        ]).

%% gen_server callbacks
-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ]).


%% API

start_link() ->
    gen_server:start_link({local,?MODULE}, ?MODULE, [], []).

s(V) ->
    Key = id(),
    undefined = c(Key, V),
    {Key, r(Key)}.
c(K,V) ->
    u(K, V).
l() ->
    [KV || KV={K,_} <- erlang:get(), is_integer(K)].
r(K) ->
    erlang:get(K).
u(K,V) ->
    erlang:put(K, V).
p(K,V) when is_map(V) ->
    NewV = maps:merge(r(K), V),
    _ = u(K, NewV),
    r(K);
p(K,V) when is_list(V) ->
    NewV = maps:merge(maps:from_list(r(K)), maps:from_list(V)),
    _ = u(K, maps:to_list(NewV)),
    r(K).
e() ->
    L = l(),
    _ = [d(K) || {K,_} <- L],
    L.
d(K) ->
    erlang:erase(K).

get() ->
    gen_server:call(?MODULE, ?FUNCTION_NAME).
get(Key) ->
    gen_server:call(?MODULE, {?FUNCTION_NAME,Key}).
store(Value) ->
    gen_server:call(?MODULE, {?FUNCTION_NAME,Value}).
put(Key, Value) ->
    gen_server:call(?MODULE, {?FUNCTION_NAME,Key,Value}).
update(Key, Value) ->
    gen_server:call(?MODULE, {?FUNCTION_NAME,Key,Value}).
patch(Key, Value) ->
    gen_server:call(?MODULE, {?FUNCTION_NAME,Key,Value}).
erase() ->
    gen_server:call(?MODULE, ?FUNCTION_NAME).
delete(Key) ->
    gen_server:call(?MODULE, {?FUNCTION_NAME,Key}).

exists(Key) ->
    gen_server:call(?MODULE, {peek,Key}).

id() ->
    binary_to_integer(
      binary:part(float_to_binary(rand:uniform()), 2, 8)).


%% gen_server Internals

init([]) ->
    AKey = 12300678,
    AValue = #{<<"a">> => <<"thing">>},
    {ok, #{AKey => AValue}}.

handle_call({store, Value0}, _From, State) ->
    {Key,Value} = s(Value0),
    {reply, Value#{<<"id">> => Key}, State};
handle_call({put, Key, Value}, _From, State) ->
    _ = c(Key,Value),
    V = r(Key),
    {reply, V#{<<"id">> => Key}, State};
handle_call(get, _From, State) ->
    L = [V#{<<"id">> => K} || {K,V} <- l()],
    {reply, L, State};
handle_call({get, Key}, _From, State) ->
    Value = r(Key),
    {reply, Value#{<<"id">> => Key}, State};
handle_call({update, Key, Value}, _From, State) ->
    _old = u(Key, Value),
    V = r(Key),
    {reply, V#{<<"id">> => Key}, State};
handle_call({patch, Key, Value}, _From, State) ->
    V = p(Key, Value),
    {reply, V#{<<"id">> => Key}, State};
handle_call({delete, Key}, _From, State) ->
    {reply, d(Key), State};
handle_call(erase, _From, State) ->
    {stop, e(), State};
handle_call({peek, Key}, _From, State) ->
    {reply, undefined =/= r(Key), State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Internals
