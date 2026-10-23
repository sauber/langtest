# Typed view of the subset of data/meta.json needed by the evaluator.
defmodule Langtest.Meta do
  # Coin descriptor plus timeline and precomputed index metadata.
  defstruct coins: [], steps: 0, first_timestamp: 0, last_timestamp: 0, index: []

  # Reads and validates the meta file from disk.
  def load!(path) do
    path
    |> File.read!()
    |> Langtest.JSON.decode!()
    |> from_map()
  end

  # Converts the decoded JSON map into the typed meta struct.
  defp from_map(map) do
    timeline = Map.fetch!(map, "timeline")
    market_index = Map.fetch!(map, "marketIndex")

    coins =
      map
      |> Map.fetch!("coins")
      |> Enum.map(fn coin ->
        %{
          symbol: Map.fetch!(coin, "symbol"),
          file: Map.fetch!(coin, "file")
        }
      end)

    %__MODULE__{
      coins: coins,
      steps: Map.fetch!(timeline, "steps"),
      first_timestamp: Map.fetch!(timeline, "firstTimestamp"),
      last_timestamp: Map.fetch!(timeline, "lastTimestamp"),
      index: Map.fetch!(market_index, "values")
    }
  end
end
