%%%-------------------------------------------------------------------
%%% @author David W. Arnold
%%% @doc CO545-Assignment-4
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(taskOne).
-author("David").

-import(monitor, [tcpMonitorStart/0]).
-import(server, [serverEstablished/5]).

%% API
-export([
  serverStart/0, clientStart/2, testOne/0
]).
%%-compile(export_all).

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
      NewS = S + 1,
      Server ! {self(), {ack, C, NewS}},
      sendMsg(Server, NewS, C, Msg)
  end.

sendMsg(Server, S, C, Msg) -> sendMsg(Server, S, C, Msg, "").

sendMsg(Server, S, C, "", "") ->
  Server ! {self(), {fin, C, S}},
  receive
    {Server, {ack, S, C}} -> io:format("Client done.~n")
  end;

sendMsg(Server, S, C, Msg, MsgToSend) when (length(MsgToSend) == 7) orelse (length(Msg) == 0) ->
  Server ! {self(), {ack, C, S, MsgToSend}},
  receive
    {Server, {ack, S, NewC}} ->
      sendMsg(Server, S, NewC, Msg, "")
  end;

sendMsg(Server, S, C, [Char | Rest], MsgToSend) ->
  sendMsg(Server, S, C, Rest, MsgToSend ++ [Char]).

%% 1.3 -------------------------------------------------------------------

%% tcpMonitorStart/0 starts off by waiting for a tuple consisting of
%% the address of the client and the address of the server that we'll be monitoring traffic between.

%% When the tuple consisting of the two addresses is received,
%% the function tcpMonitor/2 is called with the client and server addresses as parameters.

%% tcpMonitor/2 is waiting to receive an ipPacket either from the client or from the server.

%% If tcpMonitor/2 receives an ipPacket from the client,
%% it forwards the tcpPacket to the server,
%% and calls the debug/3 function with parameters: client address, client address, and the tcpPacket.

%% If tcpMonitor/2 receives an ipPacket from the server,
%% it forwards the tcpPacket to the client,
%% and calls the debug/3 function with parameters: client address, server address, and the tcpPacket.

%% Each time debug/3 function is called in one of the above ways,
%% using the io:fwrite/2 function, a line is written to the standard output so we can see
%% the contents of each ipPacket being sent between client and server.

%% 1.4 -------------------------------------------------------------------

%% Run on CLI: c(monitor), c(server), c(test), c(taskOne), taskOne:testOne().
testOne() ->
  Monitor = spawn(monitor, tcpMonitorStart, []),
  Client = spawn(?MODULE, clientStart, [Monitor, "Small piece of text"]),
  Server = spawn(?MODULE, serverStart, []),
  Monitor ! {Client, Server}.
