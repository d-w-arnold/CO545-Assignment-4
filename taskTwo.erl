%%%-------------------------------------------------------------------
%%% @author David W. Arnold
%%% @doc CO545-Assignment-4
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(taskTwo).
-author("David").

-import(server, [serverEstablished/5]).
-import(taskOne, [serverStart/0]).

%% API
-export([
  lossyNetwork/0, clientStartRobust/2, testTwo/0
]).
%%-compile(export_all).

-define(Timeout, 2000).

%% 2.1 -------------------------------------------------------------------

lossyNetwork() ->
  receive
    {Client, Server} -> communication(Client, Server)
  end.

communication(Client, Server) ->
  receive
    {Client, TCP} ->
      case rand:uniform(2) - 1 of
        0 -> debug(Client, Client, TCP, fail);
        1 -> Server ! {self(), TCP}, debug(Client, Client, TCP, success)
      end;
    {Server, TCP} -> Client ! {self(), TCP}, debug(Client, Server, TCP, success)
  end,
  communication(Client, Server).

debug(Client, P, TCP, Result) ->
  case P == Client of
    true -> io:fwrite("~s {Client, ~p}~n", [arrow(Result), TCP]);
    false -> io:fwrite("<--- {Server, ~p}~n", [TCP])
  end.

arrow(Result) ->
  case Result of
    fail -> "-> X";
    success -> "--->"
  end.

%% 2.2 -------------------------------------------------------------------

clientStartRobust(Server, Msg) ->
  Server ! {self(), {syn, 0, 0}},
  receive
    {Server, {synack, S, C}} -> Server ! {self(), {ack, C, S + 1}},
      case dataTransmission(Server, S + 1, C, Msg) of
        complete -> io:fwrite("Client done.~n")
      end
  after
    ?Timeout -> clientStartRobust(Server, Msg)
  end.

dataTransmission(Server, S, C, Msg) -> dataTransmission(Server, S, C, Msg, "", fail).

dataTransmission(Server, S, C, "", "", Handshake) ->
  Server ! {self(), {fin, C, S}},
  receive
    {Server, {ack, S, C}} -> complete
  after
    ?Timeout -> dataTransmission(Server, S, C, "", "", Handshake)
  end;
dataTransmission(Server, S, C, Msg, Data, Handshake) when (length(Data) == 7) orelse (length(Msg) == 0) ->
  Server ! {self(), {ack, C, S, Data}},
  receive
    {Server, {ack, S, NewC}} -> dataTransmission(Server, S, NewC, Msg, "", success)
  after
    ?Timeout ->
      case Handshake of
        fail -> Server ! {self(), {ack, C, S}}, dataTransmission(Server, S, C, Msg, Data, Handshake);
        success -> dataTransmission(Server, S, C, Msg, Data, Handshake)
      end
  end;
dataTransmission(Server, S, C, [Char | Rest], Data, Handshake) ->
  dataTransmission(Server, S, C, Rest, Data ++ [Char], Handshake).

%% Run on CLI, in the Erlang shell:
%% c(monitor), c(server), c(taskOne), c(taskTwo), taskTwo:testTwo().

testTwo() ->
  Monitor = spawn(?MODULE, lossyNetwork, []),
  Client = spawn(?MODULE, clientStartRobust, [Monitor, "Small piece of text"]),
  Server = spawn(taskOne, serverStart, []),
  Monitor ! {Client, Server}.
