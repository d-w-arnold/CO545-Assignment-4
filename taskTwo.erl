%%%-------------------------------------------------------------------
%%% @author David W. Arnold
%%% @doc CO545-Assignment-4
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(taskTwo).
-author("David").

-import(taskOne, [serverStart/0]).

%% API
-export([
  lossyNetwork/2, clientStartRobust/2, testTwo/0
]).
%%-compile(export_all).

%% Run on CLI:
%% c(monitor), c(server), c(taskOne), c(taskTwo), taskTwo:testTwo().

%% 2.1 -------------------------------------------------------------------

lossyNetworkStart() ->
  receive
    {Client, Server} -> lossyNetwork(Client, Server)
  end.

lossyNetwork(Client, Server) ->
  receive
    {Client, TCP} -> case rand:uniform(2) - 1 of
                       0 -> debug(Client, Client, TCP, true);
                       1 -> Server ! {self(), TCP}, debug(Client, Client, TCP, false)
                     end;
    {Server, TCP} -> Client ! {self(), TCP}, debug(Client, Server, TCP, false)
  end,
  lossyNetwork(Client, Server).

debug(Client, P, TCP, Lossed) ->
  case P == Client of
    true -> io:fwrite("~s {Client, ~p}~n", [arrow(Lossed), TCP]);
    false -> io:fwrite("<--- {Server, ~p)~n", [TCP])
  end.

arrow(Lossed) ->
  case Lossed of
    true -> "-> X";
    false -> "--->"
  end.

%% 2.2 -------------------------------------------------------------------

timeout() -> 2000.

clientStartRobust(Server, Msg) ->
  Server ! {self(), {syn, 0, 0}},
  receive
    {Server, {synack, S, C}} ->
      Server ! {self(), {ack, C, S + 1}},
      sendMsg(Server, S + 1, C, Msg)
  after
    timeout() -> clientStartRobust(Server, Msg)
  end.

sendMsg(Server, S, C, Msg) -> sendMsg(Server, S, C, Msg, "").

sendMsg(Server, S, C, "", "") ->
  Server ! {self(), {fin, C, S}},
  receive
    {Server, {ack, S, C}} -> io:format("Client done.~n", [])
  after
    timeout() -> sendMsg(Server, S, C, "", "")
  end;

sendMsg(Server, S, C, Msg, Candidate)
  when (length(Candidate) == 7) orelse (length(Msg) == 0) ->
  Server ! {self(), {ack, C, S, Candidate}},
  receive
    {Server, {ack, S, NewC}} ->
      sendMsg(Server, S, NewC, Msg, "")
  after
    timeout() -> sendMsg(Server, S, C, Msg, Candidate)
  end;

sendMsg(Server, S, C, [Char | Rest], Candidate) ->
  sendMsg(Server, S, C, Rest, Candidate ++ [Char]).

testTwo() ->
  Server = spawn(taskOne, serverStart, []),
  Monitor = spawn(fun() -> lossyNetworkStart() end),
  Client = spawn(?MODULE, clientStartRobust, [Monitor, "A small piece of text"]),
  Monitor ! {Client, Server}.
