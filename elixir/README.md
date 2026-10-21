# Elixir — trading strategy evaluator

RSI(14) trading strategy evaluator implemented in Elixir for comparison against the Deno baseline.

## How to run the test suite

```sh
cd elixir
mix test
```

The unit tests cover Wilder's RSI, simulator rules, and performance metrics.

## How to run the evaluation

```sh
cd elixir
mix escript.build
./langtest
```

A different data directory can be passed explicitly:

```sh
./langtest --data=/path/to/csv-directory
```

## Build commands

```sh
cd elixir
mix format        # format the codebase
mix compile       # compile the project
mix test          # run the test suite
mix escript.build # build the standalone executable
```
