%%%-------------------------------------------------------------------
%%% @author David W. Arnold
%%% @doc CO545-Assignment-4
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(taskTwo).
-author("David").

-import(server, [serverEstablished/5]).

%% API
-export([
  lossyNetwork/2, clientStartRobust/2, testTwo/0
]).
%%-compile(export_all).

-define(Timeout, 2000).
%%-define(MaxFails, 3).

%% Run on CLI:
%% c(monitor), c(server), c(taskOne), c(taskTwo), taskTwo:testTwo().

%%%% 2.1 -------------------------------------------------------------------
%%
%%%% A duplicated server to handle restarting after Timeout * MaxFails (2000 * 3 = 60000 milli-seconds).
%%serverStart() -> serverStart(0).
%%
%%serverStart(S) ->
%%  receive
%%    {Client, {syn, C, _}} ->
%%      Client ! {self(), {synack, S, C + 1}},
%%      NewS = S + 1,
%%      receive
%%        {Client, {ack, NewC, NewS}} ->
%%          serverEstablished(Client, NewS, NewC, "", 0),
%%          serverStart(NewS)
%%      after
%%        ?Timeout * ?MaxFails -> serverStart(NewS)
%%      end
%%  end.
%%
%%lossyNetworkStart() ->
%%  % Wait to be sent the address of the client and the address
%%  % of the server that I will be monitoring traffic between.
%%  receive
%%    {Client, Server} -> lossyNetwork(Client, Server)
%%  end.
%%
%%lossyNetwork(Client, Server) ->
%%  receive
%%    {Client, TCP} -> case rand:uniform(2) - 1 of
%%                       0 -> debug(Client, Client, TCP, true);
%%                       1 -> Server ! {self(), TCP}, debug(Client, Client, TCP, false)
%%                     end;
%%    {Server, TCP} -> Client ! {self(), TCP}, debug(Client, Server, TCP, false)
%%  end,
%%  lossyNetwork(Client, Server).
%%
%%debug(Client, P, TCP, Failed) ->
%%  case P == Client of
%%    true -> io:fwrite("~s {Client, ~p}~n", [arrow(Failed), TCP]);
%%    false -> io:fwrite("<--- {Server, ~p)~n", [TCP])
%%  end.
%%
%%arrow(Failed) ->
%%  case Failed of
%%    true -> "-> X";
%%    false -> "--->"
%%  end.
%%
%%%% 2.2 -------------------------------------------------------------------
%%
%%clientStartRobust(Server, Msg) ->
%%  Server ! {self(), {syn, 0, 0}},
%%  receive
%%    {Server, {synack, S, C}} ->
%%      NewS = S + 1,
%%      Server ! {self(), {ack, C, NewS}},
%%
%%      case sendMessage(Server, NewS, C, Msg) of
%%        success -> io:format("Client done.~n", []);
%%        maxFails ->
%%          io:format("Connection reset...~n"),
%%          clientStartRobust(Server, Msg)
%%      end
%%  after
%%    ?Timeout -> clientStartRobust(Server, Msg)
%%  end.
%%
%%sendMessage(Server, S, C, Msg) -> sendMessage(Server, S, C, Msg, "", 0).
%%
%%sendMessage(_, _, _, _, _, ?MaxFails) -> maxFails;
%%
%%sendMessage(Server, S, C, "", "", Fails) ->
%%  Server ! {self(), {fin, C, S}},
%%  receive
%%    {Server, {ack, S, C}} -> success
%%  after
%%    ?Timeout -> sendMessage(Server, S, C, "", "", Fails + 1)
%%  end;
%%
%%sendMessage(Server, S, C, Msg, Candidate, Fails) when (length(Candidate) == 7) orelse (length(Msg) == 0) ->
%%  Server ! {self(), {ack, C, S, Candidate}},
%%  receive
%%    {Server, {ack, S, NewC}} ->
%%      sendMessage(Server, S, NewC, Msg, "", 0)
%%  after
%%    ?Timeout -> sendMessage(Server, S, C, Msg, Candidate, Fails + 1)
%%  end;
%%
%%sendMessage(Server, S, C, [Char | Rest], Candidate, Fails) ->
%%  sendMessage(Server, S, C, Rest, Candidate ++ [Char], Fails).
%%
%%testTwo() ->
%%  Server = spawn(fun() -> serverStart() end),
%%  Monitor = spawn(fun() -> lossyNetworkStart() end),
%%  Client = spawn(?MODULE, clientStartRobust, [Monitor, "Small piece of text"]),
%%  Monitor ! {Client, Server}.

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

clientStartRobust(Server, Msg) ->
  Server ! {self(), {syn, 0, 0}},
  receive
    {Server, {synack, S, C}} ->
      Server ! {self(), {ack, C, S + 1}},
      sendMsg(Server, S + 1, C, Msg)
  after
    ?Timeout -> clientStartRobust(Server, Msg)
  end.

sendMsg(Server, S, C, Msg) -> sendMsg(Server, S, C, Msg, "").

sendMsg(Server, S, C, "", "") ->
  Server ! {self(), {fin, C, S}},
  receive
    {Server, {ack, S, C}} -> io:format("Client done.~n", [])
  after
    ?Timeout -> sendMsg(Server, S, C, "", "")
  end;

sendMsg(Server, S, C, Msg, Candidate)
  when (length(Candidate) == 7) orelse (length(Msg) == 0) ->
  Server ! {self(), {ack, C, S, Candidate}},
  receive
    {Server, {ack, S, NewC}} ->
      sendMsg(Server, S, NewC, Msg, "")
  after
    ?Timeout -> sendMsg(Server, S, C, Msg, Candidate)
  end;

sendMsg(Server, S, C, [Char | Rest], Candidate) ->
  sendMsg(Server, S, C, Rest, Candidate ++ [Char]).

testTwo() ->
  Server = spawn(taskOne, serverStart, []),
  Monitor = spawn(fun() -> lossyNetworkStart() end),
  Client = spawn(?MODULE, clientStartRobust, [Monitor, "A small piece of text"]),
  Monitor ! {Client, Server}.
