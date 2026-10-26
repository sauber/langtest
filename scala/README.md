# Scala 3 implementation

## Run tests
From repository root:
```
scala-cli test scala/
```
From the scala/ directory:
```
scala-cli test .
```

## Run evaluation
From repository root:
```
scala-cli run scala/
```
From the scala/ directory:
```
scala-cli run .
```

## Build
```
scala-cli compile scala/
```

Notes: data is read from `data/` (or `../data/` when run from `scala/`). Output fits an 80x25 terminal.