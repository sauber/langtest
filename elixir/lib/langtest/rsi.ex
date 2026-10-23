# Incremental Wilder smoothing for the 14-period Relative Strength Index.
defmodule Langtest.RSI do
  # Wilder's standard RSI lookback period.
  @period 14

  # Immutable indicator state carried from one close to the next.
  defstruct prev_close: nil,
            period: 14,
            changes: 0,
            gain_sum: 0.0,
            loss_sum: 0.0,
            avg_gain: nil,
            avg_loss: nil

  # Creates a fresh RSI state for the requested period.
  def new(period \\ @period) do
    %__MODULE__{period: period}
  end

  # Feeds one close into the state and returns the updated state with RSI or nil.
  def update(%__MODULE__{prev_close: nil} = state, close) do
    {%{state | prev_close: close}, nil}
  end

  # Accumulates the warm-up changes and emits the first RSI on the final warm-up change.
  def update(%__MODULE__{avg_gain: nil} = state, close) do
    {gain, loss} = change(state.prev_close, close)
    changes = state.changes + 1
    gain_sum = state.gain_sum + gain
    loss_sum = state.loss_sum + loss

    if changes == state.period do
      avg_gain = gain_sum / state.period
      avg_loss = loss_sum / state.period

      state = %{
        state
        | prev_close: close,
          changes: changes,
          gain_sum: gain_sum,
          loss_sum: loss_sum,
          avg_gain: avg_gain,
          avg_loss: avg_loss
      }

      {state, from_averages(avg_gain, avg_loss)}
    else
      {%{
         state
         | prev_close: close,
           changes: changes,
           gain_sum: gain_sum,
           loss_sum: loss_sum
       }, nil}
    end
  end

  # Applies Wilder's smoothing to each subsequent close and returns the new RSI.
  def update(%__MODULE__{} = state, close) do
    {gain, loss} = change(state.prev_close, close)
    period = state.period
    avg_gain = (state.avg_gain * (period - 1) + gain) / period
    avg_loss = (state.avg_loss * (period - 1) + loss) / period

    state = %{state | prev_close: close, avg_gain: avg_gain, avg_loss: avg_loss}
    {state, from_averages(avg_gain, avg_loss)}
  end

  # Computes the positive and negative price change components.
  defp change(previous, current) do
    delta = current - previous

    if delta >= 0.0 do
      {delta, 0.0}
    else
      {0.0, -delta}
    end
  end

  # Converts smoothed average gain/loss into a bounded RSI value.
  defp from_averages(avg_gain, avg_loss) do
    cond do
      avg_gain == 0.0 and avg_loss == 0.0 -> 50.0
      avg_loss == 0.0 -> 100.0
      avg_gain == 0.0 -> 0.0
      true -> 100.0 - 100.0 / (1.0 + avg_gain / avg_loss)
    end
  end
end
