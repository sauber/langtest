-- The character chart of the equity curve and the market index.

module Chart exposing (Chart, render)

import Format exposing (axisValue)

-- The two series of the chart together with the labels of the timeline.
type alias Chart =
    { equity : List Float
    , index : List Float
    , fromLabel : String
    , toLabel : String
    }

-- The colour of a plotted line.
type Color
    = EquityColor
    | IndexColor

-- One marked cell of the plot area.
type alias Mark =
    { symbol : String
    , color : Color
    }

-- The plot area: rows of cells, the top row first.
type alias Grid =
    List (List (Maybe Mark))

-- The number of columns of the plot area.
columns : Int
columns =
    69

-- The number of rows of the plot area.
rows : Int
rows =
    15

-- The width of the whole chart.
width : Int
width =
    78

-- Renders the chart of the equity curve and the market index.
render : Chart -> List String
render chart =
    let
        values = chart.equity ++ chart.index
        maximum = Maybe.withDefault 1 (List.maximum values)
        minimum = Maybe.withDefault 0 (List.minimum values)
        grid =
            merge
                (drawSeries chart.equity maximum minimum EquityColor)
                (drawSeries chart.index maximum minimum IndexColor)
    in
    List.append
        [ topBorder ]
        (List.append
            (List.indexedMap (\row cells -> renderRow row maximum minimum cells) grid)
            [ bottomBorder chart.fromLabel chart.toLabel, legend ]
        )

-- Draws one series into the plot area.
drawSeries : List Float -> Float -> Float -> Color -> Grid
drawSeries values maximum minimum color =
    let
        points =
            List.map
                (\column -> pointOf values maximum minimum column)
                (List.range 0 (columns - 1))
    in
    paint points (emptyGrid) color

-- Maps a column of the chart to the row that holds its value.
pointOf : List Float -> Float -> Float -> Int -> ( Int, Int )
pointOf values maximum minimum column =
    let
        index = sampleIndex (List.length values) column
        value = nthOrZero values index
        span = maximum - minimum
    in
    ( column
    , if span <= 0 then
        rows - 1

      else
        round ((maximum - value) / span * toFloat (rows - 1))
    )

-- Picks the position of a curve that a column shows.
sampleIndex : Int -> Int -> Int
sampleIndex length column =
    if length <= 1 then
        0

    else
        round (toFloat column / toFloat (columns - 1) * toFloat (length - 1))

-- Reads the value at a position of a curve.
nthOrZero : List Float -> Int -> Float
nthOrZero values index =
    values
        |> List.drop index
        |> List.head
        |> Maybe.withDefault 0

-- Draws the line of a series into the plot area.
paint : List ( Int, Int ) -> Grid -> Color -> Grid
paint points grid color =
    case points of
        [] ->
            grid

        ( column, row ) :: rest ->
            paintSteps ( column, row ) rest (mark column row "╭" color grid) color

-- Draws the steps between the points of a series.
paintSteps : ( Int, Int ) -> List ( Int, Int ) -> Grid -> Color -> Grid
paintSteps ( _, previousRow ) points grid color =
    case points of
        [] ->
            grid

        ( column, row ) :: rest ->
            let
                symbol =
                    if row > previousRow then
                        "╮"

                    else if row < previousRow then
                        "╰"

                    else
                        "─"
            in
            paintSteps ( column, row ) rest (mark column row symbol color grid) color

-- Marks one cell of the plot area with a symbol and a colour.
mark : Int -> Int -> String -> Color -> Grid -> Grid
mark column row symbol color grid =
    case elementAt row grid of
        Nothing ->
            grid

        Just cells ->
            replaceAt row (replaceAt column (Just { symbol = symbol, color = color }) cells) grid

-- Reads the element at a position of a list.
elementAt : Int -> List a -> Maybe a
elementAt index values =
    case values of
        [] ->
            Nothing

        first :: rest ->
            if index == 0 then
                Just first

            else
                elementAt (index - 1) rest

-- Replaces the element at a position of a list.
replaceAt : Int -> a -> List a -> List a
replaceAt index value values =
    case values of
        [] ->
            []

        first :: rest ->
            if index == 0 then
                value :: rest

            else
                first :: replaceAt (index - 1) value rest

-- Builds an empty plot area.
emptyGrid : Grid
emptyGrid =
    List.repeat rows (List.repeat columns Nothing)

-- Merges the two grids of the chart; the equity curve wins over the index.
merge : Grid -> Grid -> Grid
merge equityGrid indexGrid =
    List.map2 mergeRow equityGrid indexGrid

-- Merges two rows of the plot area.
mergeRow : List (Maybe Mark) -> List (Maybe Mark) -> List (Maybe Mark)
mergeRow equityCells indexCells =
    List.map2
        (\equity index ->
            case equity of
                Just _ ->
                    equity

                Nothing ->
                    index
        )
        equityCells
        indexCells

-- Renders one row of the chart with its axis label.
renderRow : Int -> Float -> Float -> List (Maybe Mark) -> String
renderRow row maximum minimum cells =
    "│"
        ++ axisLabel row maximum minimum
        ++ String.join "" (List.map renderCell cells)
        ++ "│"

-- Builds the axis label of a chart row.
axisLabel : Int -> Float -> Float -> String
axisLabel row maximum minimum =
    let
        middle = (rows - 1) // 2
        label =
            if row == 0 then
                axisValue maximum

            else if row == rows - 1 then
                axisValue minimum

            else if row == middle then
                axisValue ((maximum + minimum) / 2)

            else
                ""
    in
    String.padLeft 6 ' ' label ++ "┤"

-- Renders one cell of the plot area with its colour.
renderCell : Maybe Mark -> String
renderCell cell =
    case cell of
        Nothing ->
            " "

        Just marked ->
            colorCode marked.color ++ marked.symbol ++ colorReset

-- The escape sequence that starts the colour of a line.
colorCode : Color -> String
colorCode color =
    case color of
        EquityColor ->
            "\u{001B}[36m"

        IndexColor ->
            "\u{001B}[35m"

-- The escape sequence that ends the colour of a line.
colorReset : String
colorReset =
    "\u{001B}[0m"

-- The top border of the chart.
topBorder : String
topBorder =
    "╭" ++ String.repeat (width - 2) "─" ++ "╮"

-- The bottom border of the chart with the labels of the timeline.
bottomBorder : String -> String -> String
bottomBorder fromLabel toLabel =
    "╰─ "
        ++ String.padRight 10 ' ' fromLabel
        ++ " "
        ++ String.repeat (width - 27) "─"
        ++ " "
        ++ String.padLeft 10 ' ' toLabel
        ++ " ╯"

-- The legend below the chart.
legend : String
legend =
    colorCode EquityColor
        ++ "●"
        ++ colorReset
        ++ " strategy equity (cyan)   "
        ++ colorCode IndexColor
        ++ "●"
        ++ colorReset
        ++ " market index (magenta, shared axis)"
