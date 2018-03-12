%%%-------------------------------------------------------------------
%%% @author David W. Arnold
%%% @doc CO545-Assignment-4
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(taskOne).
-author("David").

-import(server, [serverEstablished/5]).
-import(monitor, [tcpMonitorStart/0]).

%% API
-export([
  serverStart/0, clientStart/2, testOne/0
]).
%%-compile(export_all).

%% Run on CLI:
%% c(test), c(taskOne), c(monitor), c(server), taskOne:testOne().

%% 1.1 -------------------------------------------------------------------

serverStart() -> serverStart(0).

serverStart(S) ->
  receive
    {Client, {syn, C, _}} ->
      Client ! {self(), {synack, S, C + 1}},
      receive
        {Client, {ack, NewC, NewS}} ->
          serverStart(serverEstablished(Client, NewS, NewC, "", 0))
      end
  end.

%% 1.2 -------------------------------------------------------------------

clientStart(Server, Msg) ->
  Server ! {self(), {syn, 0, 0}},
  receive
    {Server, {synack, S, C}} ->
      Server ! {self(), {ack, C, S + 1}},
      sendMsg(Server, S + 1, C, Msg)
  end.

sendMsg(Server, S, C, Msg) -> sendMsg(Server, S, C, Msg, "").

sendMsg(Server, S, C, "", "") ->
  Server ! {self(), {fin, C, S}},
  receive
    {Server, {ack, S, C}} -> io:format("Client done.~n", [])
  end;

sendMsg(Server, S, C, Msg, Candidate) when (length(Candidate) == 7) orelse (length(Msg) == 0) ->
  Server ! {self(), {ack, C, S, Candidate}},
  receive
    {Server, {ack, S, NewC}} ->
      sendMsg(Server, S, NewC, Msg, "")
  end;

sendMsg(Server, S, C, [Char | Rest], Candidate) ->
  sendMsg(Server, S, C, Rest, Candidate ++ [Char]).

%% 1.3 -------------------------------------------------------------------

% The monitor is acting like a client and a server, if it receives a message from the client, it forwards it to the server, if it receives one from the server it forwards it to the client

%% 1.4 -------------------------------------------------------------------

testOne() ->
  Monitor = spawn(monitor, tcpMonitorStart, []),
  Client = spawn(?MODULE, clientStart, [Monitor, "A small piece of text"]),
  Server = spawn(?MODULE, serverStart, []),
  Monitor ! {Client, Server}.
