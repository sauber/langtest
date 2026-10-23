module Format exposing (fixed, groupThousands)

{-| Small deterministic number formatting helpers for the terminal report.
-}


-- Ten raised to an integer power
pow10 : Int -> Int
pow10 exponent =
    if exponent <= 0 then
        1

    else
        10 * pow10 (exponent - 1)


-- Insert thousands separators into a non-negative integer
groupThousands : Int -> String
groupThousands value =
    let
        digits =
            String.fromInt (abs value)

        reversed =
            List.reverse (String.toList digits)
    in
    String.fromList (List.reverse (insertCommas 0 reversed))


-- Walk digits least-significant first and add a comma every three places
insertCommas : Int -> List Char -> List Char
insertCommas count chars =
    case chars of
        [] ->
            []

        c :: rest ->
            if count > 0 && modBy 3 count == 0 then
                ',' :: c :: insertCommas (count + 1) rest

            else
                c :: insertCommas (count + 1) rest


-- Fixed-point rendering with comma grouping and a leading minus sign
fixed : Int -> Float -> String
fixed decimals value =
    let
        factor =
            pow10 decimals

        sign =
            if value < 0 then
                "-"

            else
                ""

        scaled =
            round (abs value * toFloat factor)

        whole =
            scaled // factor

        fraction =
            modBy factor scaled

        decimalPart =
            if decimals > 0 then
                "." ++ String.padLeft decimals '0' (String.fromInt fraction)

            else
                ""
    in
    sign ++ groupThousands whole ++ decimalPart
