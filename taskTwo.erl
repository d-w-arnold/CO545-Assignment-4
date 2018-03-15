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
    false -> io:fwrite("<--- {Server, ~p)~n", [TCP])
  end.

arrow(Result) ->
  case Result of
    fail -> "-->X";
    success -> "--->"
  end.

%% 2.2 -------------------------------------------------------------------

clientStartRobust(Server, Msg) ->
  Server ! {self(), {syn, 0, 0}},
  receive
    {Server, {synack, S, C}} ->
      NewS = S + 1,
      Server ! {self(), {ack, C, NewS}},
      case sendMsg(Server, NewS, C, Msg) of
        success -> io:fwrite("Client done.~n")
      end
  after
    ?Timeout -> clientStartRobust(Server, Msg)
  end.

sendMsg(Server, S, C, Msg) -> sendMsg(Server, S, C, Msg, "", false).

sendMsg(Server, S, C, "", "", HandshakeComplete) ->
  Server ! {self(), {fin, C, S}},
  receive
    {Server, {ack, S, C}} -> success
  after
    ?Timeout -> sendMsg(Server, S, C, "", "", HandshakeComplete)
  end;
sendMsg(Server, S, C, Msg, MsgToSend, HandshakeComplete) when (length(MsgToSend) == 7) orelse (length(Msg) == 0) ->
  Server ! {self(), {ack, C, S, MsgToSend}},
  receive
    {Server, {ack, S, NewC}} ->
      sendMsg(Server, S, NewC, Msg, "", true)
  after
    ?Timeout ->
      case HandshakeComplete of
        false -> Server ! {self(), {ack, C, S}}, sendMsg(Server, S, C, Msg, MsgToSend, HandshakeComplete);
        true -> sendMsg(Server, S, C, Msg, MsgToSend, HandshakeComplete)
      end
  end;
sendMsg(Server, S, C, [Char | Rest], MsgToSend, HandshakeComplete) ->
  sendMsg(Server, S, C, Rest, MsgToSend ++ [Char], HandshakeComplete).

%% Run on CLI: c(monitor), c(server), c(taskOne), c(taskTwo), taskTwo:testTwo().
testTwo() ->
  Monitor = spawn(?MODULE, lossyNetwork, []),
  Client = spawn(?MODULE, clientStartRobust, [Monitor, "Small piece of text"]),
  Server = spawn(taskOne, serverStart, []),
  Monitor ! {Client, Server}.
