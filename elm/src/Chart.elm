module Chart exposing (legend, render)

import Array exposing (Array)

{-| Two-series terminal line chart drawn with soft box characters and ANSI color.
-}


-- One raster cell of the plotting area
type Cell
    = Empty
    | Glyph Int Char


-- ANSI color for one series identity
colorCode : Int -> String
colorCode identity =
    if identity == 1 then
        "\u{001B}[96m"

    else
        "\u{001B}[93m"


-- Reset sequence after every colored glyph
reset : String
reset =
    "\u{001B}[0m"


-- Colored legend line telling the two series apart
legend : String
legend =
    colorCode 1 ++ "── strategy" ++ reset ++ "   " ++ colorCode 2 ++ "── index" ++ reset


-- Render the strategy and index series inside a framed chart
render : Int -> Int -> List Float -> List Float -> List String
render width height strategy index =
    let
        cells =
            Array.repeat (width * height) Empty
                |> drawSeries width height 2 (shape height (sample width index))
                |> drawSeries width height 1 (shape height (sample width strategy))

        top =
            "  ╭" ++ String.repeat width "─" ++ "╮"

        bottom =
            "  ╰" ++ String.repeat width "─" ++ "╯"

        rows =
            List.range 0 (height - 1)
                |> List.map (\y -> "  │" ++ renderRow width y cells ++ "│")
    in
    top :: rows ++ [ bottom ]


-- Average the series into one value per chart column
sample : Int -> List Float -> Array Float
sample width values =
    let
        source =
            Array.fromList values

        count =
            Array.length source
    in
    if count == 0 || width <= 0 then
        Array.repeat (max width 0) 0

    else
        Array.initialize width (\column -> averageRange source (column * count // width) ((column + 1) * count // width))


-- Mean of an index range, clamped to at least one element
averageRange : Array Float -> Int -> Int -> Float
averageRange source start end =
    let
        stop =
            min end (Array.length source)

        count =
            stop - start
    in
    if count <= 0 then
        0

    else
        sumRange source start stop 0 / toFloat count


-- Accumulate a range of array values
sumRange : Array Float -> Int -> Int -> Float -> Float
sumRange source index end acc =
    if index >= end then
        acc

    else
        case Array.get index source of
            Just value ->
                sumRange source (index + 1) end (acc + value)

            Nothing ->
                acc


-- Map sampled values onto row coordinates, with higher values on top
shape : Int -> Array Float -> Array Int
shape height values =
    let
        list =
            Array.toList values

        low =
            List.foldl min (List.foldl max 0 list) list

        high =
            List.foldl max low list
    in
    if high == low then
        Array.map (\_ -> height // 2) values

    else
        Array.map
            (\value -> height - 1 - round ((value - low) / (high - low) * toFloat (height - 1)))
            values


-- Draw one series, connecting adjacent columns with vertical runs and corners
drawSeries : Int -> Int -> Int -> Array Int -> Array Cell -> Array Cell
drawSeries width height identity rows cells =
    List.foldl (drawColumn width height identity rows) cells (List.range 0 (width - 1))


-- Add the segment that enters one column from the previous one
drawColumn : Int -> Int -> Int -> Array Int -> Int -> Array Cell -> Array Cell
drawColumn width height identity rows column cells =
    case Array.get column rows of
        Nothing ->
            cells

        Just row ->
            if column == 0 then
                place width height identity column row '─' cells

            else
                case Array.get (column - 1) rows of
                    Nothing ->
                        place width height identity column row '─' cells

                    Just previous ->
                        if row == previous then
                            place width height identity column row '─' cells

                        else if row < previous then
                            cells
                                |> fillVertical width height identity column previous row
                                |> place width height identity column previous '╯'
                                |> place width height identity column row '╭'

                        else
                            cells
                                |> fillVertical width height identity column previous row
                                |> place width height identity column previous '╮'
                                |> place width height identity column row '╰'


-- Fill the strictly-between rows of a column with a vertical stroke
fillVertical : Int -> Int -> Int -> Int -> Int -> Int -> Array Cell -> Array Cell
fillVertical width height identity column from to cells =
    let
        low =
            min from to

        high =
            max from to
    in
    List.range (low + 1) (high - 1)
        |> List.foldl (\row acc -> place width height identity column row '│' acc) cells


-- Merge a glyph into a cell, letting the series drawn last stay visible
mergeCell : Int -> Char -> Cell -> Cell
mergeCell identity char cell =
    case cell of
        Empty ->
            Glyph identity char

        Glyph _ _ ->
            Glyph identity char


-- Write one glyph into the flat cell grid when it is inside the plot
place : Int -> Int -> Int -> Int -> Int -> Char -> Array Cell -> Array Cell
place width height identity column row char cells =
    if column < 0 || column >= width || row < 0 || row >= height then
        cells

    else
        let
            index =
                row * width + column
        in
        case Array.get index cells of
            Just existing ->
                Array.set index (mergeCell identity char existing) cells

            Nothing ->
                cells


-- Render one chart row as spaces and colored glyphs
renderRow : Int -> Int -> Array Cell -> String
renderRow width row cells =
    List.range 0 (width - 1)
        |> List.map (\column -> renderCell (Array.get (row * width + column) cells))
        |> String.concat


-- One cell as a colored character
renderCell : Maybe Cell -> String
renderCell maybeCell =
    case maybeCell of
        Just (Glyph identity char) ->
            colorCode identity ++ String.fromChar char ++ reset

        Just Empty ->
            " "

        Nothing ->
            " "
