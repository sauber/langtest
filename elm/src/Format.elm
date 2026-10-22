-- The number formatting of the report.

module Format exposing (axisValue, fixed, group, percent)

-- Formats a number with a fixed number of decimal digits.
fixed : Int -> Float -> String
fixed digits value =
    let
        factor = 10 ^ digits
        scaled = round (value * toFloat factor)
        sign =
            if scaled < 0 then
                "-"

            else
                ""
        whole = abs scaled // factor
        fraction = modBy factor (abs scaled)
    in
    sign
        ++ group (String.fromInt whole)
        ++ "."
        ++ String.padLeft digits '0' (String.fromInt fraction)

-- Inserts thousands separators into a digit string.
group : String -> String
group digits =
    digits
        |> String.toList
        |> List.reverse
        |> chunksOf 3
        |> List.map (List.reverse >> String.fromList)
        |> List.reverse
        |> String.join ","

-- Splits a list into chunks of the given size.
chunksOf : Int -> List a -> List (List a)
chunksOf size values =
    case List.take size values of
        [] ->
            []

        chunk ->
            chunk :: chunksOf size (List.drop size values)

-- Formats a fraction as a signed percentage with four decimal digits.
percent : Float -> String
percent value =
    (if value >= 0 then
        "+"

     else
        ""
    )
        ++ fixed 4 (value * 100)
        ++ "%"

-- Formats an axis value in a compact form.
axisValue : Float -> String
axisValue value =
    if abs value >= 1000 then
        fixed 1 (value / 1000) ++ "k"

    else
        fixed 0 value
