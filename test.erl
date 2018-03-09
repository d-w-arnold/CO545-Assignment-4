starter() ->
  Server = spawn(model, serverStart, []),
  _Client1 = spawn(model, clientStart,
    [Server, "The quick brown fox jumped over the lazy dog."]),
  _Client2 = spawn(model, clientStart,
    [Server, "Contrary to popular belief, Lorem Ipsum is not simply random text."]).
