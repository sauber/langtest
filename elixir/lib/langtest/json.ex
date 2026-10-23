# Small dependency-free JSON decoder used for the generated meta file.
defmodule Langtest.JSON do
  # Decodes a complete JSON document and rejects trailing content.
  def decode!(binary) when is_binary(binary) do
    {value, rest} = parse_value(skip(binary))

    case skip(rest) do
      "" -> value
      _ -> raise ArgumentError, "trailing data after JSON document"
    end
  end

  # Dispatches on the first significant byte of a JSON value.
  defp parse_value(<<"{", rest::binary>>), do: parse_object(skip(rest), %{})
  defp parse_value(<<"[", rest::binary>>), do: parse_array(skip(rest), [])
  defp parse_value(<<"\"", rest::binary>>), do: parse_string(rest, [])
  defp parse_value(<<"true", rest::binary>>), do: {true, rest}
  defp parse_value(<<"false", rest::binary>>), do: {false, rest}
  defp parse_value(<<"null", rest::binary>>), do: {nil, rest}

  # Parses any numeric literal, including exponents and negative values.
  defp parse_value(<<c, _::binary>> = binary) when c == ?- or c in ?0..?9 do
    parse_number(binary)
  end

  # Rejects malformed JSON values with a clear error.
  defp parse_value(binary) do
    raise ArgumentError,
          "invalid JSON value at #{inspect(binary_part(binary, 0, min(byte_size(binary), 12)))}"
  end

  # Parses an object body after the opening brace.
  defp parse_object(<<"}", rest::binary>>, acc), do: {acc, rest}

  # Parses one key/value pair and continues with the next pair or closing brace.
  defp parse_object(<<"\"", rest::binary>>, acc) do
    {key, rest} = parse_string(rest, [])
    rest = skip(rest)

    case rest do
      <<":", rest::binary>> ->
        {value, rest} = parse_value(skip(rest))
        acc = Map.put(acc, key, value)

        case skip(rest) do
          <<",", rest::binary>> -> parse_object(skip(rest), acc)
          <<"}", rest::binary>> -> {acc, rest}
          _ -> raise ArgumentError, "expected ',' or '}' in JSON object"
        end

      _ ->
        raise ArgumentError, "expected ':' after JSON object key"
    end
  end

  # Rejects object bodies that do not start with a quoted key.
  defp parse_object(_other, _acc) do
    raise ArgumentError, "expected string key in JSON object"
  end

  # Parses an array body after the opening bracket.
  defp parse_array(<<"]", rest::binary>>, acc), do: {:lists.reverse(acc), rest}

  # Parses one array element and continues with the next element or closing bracket.
  defp parse_array(binary, acc) do
    {value, rest} = parse_value(binary)

    case skip(rest) do
      <<",", rest::binary>> -> parse_array(skip(rest), [value | acc])
      <<"]", rest::binary>> -> {:lists.reverse([value | acc]), rest}
      _ -> raise ArgumentError, "expected ',' or ']' in JSON array"
    end
  end

  # Parses a quoted string, accumulating unescaped fragments in reverse order.
  defp parse_string(<<"\"", rest::binary>>, acc),
    do: {IO.iodata_to_binary(:lists.reverse(acc)), rest}

  defp parse_string(<<"\\\"", rest::binary>>, acc), do: parse_string(rest, ["\"" | acc])
  defp parse_string(<<"\\\\", rest::binary>>, acc), do: parse_string(rest, ["\\" | acc])
  defp parse_string(<<"\\/", rest::binary>>, acc), do: parse_string(rest, ["/" | acc])
  defp parse_string(<<"\\b", rest::binary>>, acc), do: parse_string(rest, ["\b" | acc])
  defp parse_string(<<"\\f", rest::binary>>, acc), do: parse_string(rest, ["\f" | acc])
  defp parse_string(<<"\\n", rest::binary>>, acc), do: parse_string(rest, ["\n" | acc])
  defp parse_string(<<"\\r", rest::binary>>, acc), do: parse_string(rest, ["\r" | acc])
  defp parse_string(<<"\\t", rest::binary>>, acc), do: parse_string(rest, ["\t" | acc])

  # Decodes a \uXXXX escape into its UTF-8 representation.
  defp parse_string(<<"\\u", hex::binary-size(4), rest::binary>>, acc) do
    codepoint = String.to_integer(hex, 16)
    parse_string(rest, [<<codepoint::utf8>> | acc])
  end

  # Copies one UTF-8 codepoint into the string accumulator.
  defp parse_string(<<codepoint::utf8, rest::binary>>, acc) do
    parse_string(rest, [<<codepoint::utf8>> | acc])
  end

  # Rejects strings that are not terminated with a closing quote.
  defp parse_string(<<>>, _acc) do
    raise ArgumentError, "unterminated JSON string"
  end

  # Reads a numeric literal and converts it to an integer or float.
  defp parse_number(binary) do
    {chars, rest} = take_number(binary, [])
    str = IO.iodata_to_binary(chars)

    value =
      case :binary.match(str, [".", "e", "E"]) do
        :nomatch -> :erlang.binary_to_integer(str)
        _float_marker -> :erlang.binary_to_float(normalize_exponent(str))
      end

    {value, rest}
  end

  # Accumulates the bytes that may legally belong to a JSON number.
  defp take_number(<<c, rest::binary>>, acc) when c in ~c"0123456789+-.eE" do
    take_number(rest, [c | acc])
  end

  # Stops number scanning at the first non-numeric byte.
  defp take_number(rest, acc), do: {:lists.reverse(acc), rest}

  # Ensures Erlang's float parser receives a decimal point when an exponent is present.
  defp normalize_exponent(str) do
    case :binary.match(str, ["e", "E"]) do
      :nomatch ->
        str

      {pos, _len} ->
        mantissa = binary_part(str, 0, pos)
        exponent = binary_part(str, pos, byte_size(str) - pos)

        if String.contains?(mantissa, ".") do
          mantissa <> exponent
        else
          mantissa <> ".0" <> exponent
        end
    end
  end

  # Skips JSON whitespace between tokens.
  defp skip(<<c, rest::binary>>) when c in [?\s, ?\t, ?\n, ?\r], do: skip(rest)
  defp skip(binary), do: binary
end
