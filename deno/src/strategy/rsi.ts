// Converts an average gain and loss pair into the RSI value it implies.
function rsiFrom(gain: number, loss: number): number {
  if (loss === 0) return 100;
  return 100 - 100 / (1 + gain / loss);
}

// Computes Wilder's RSI over a close-price series, marking bars without a value as NaN.
export function wilderRsi(closes: ArrayLike<number>, period = 14): Float64Array {
  const bars = closes.length;
  const rsi = new Float64Array(bars).fill(NaN);
  if (bars <= period) return rsi;
  let gain = 0;
  let loss = 0;
  for (let bar = 1; bar <= period; bar++) {
    const change = closes[bar] - closes[bar - 1];
    if (change > 0) gain += change;
    else loss -= change;
  }
  gain /= period;
  loss /= period;
  rsi[period] = rsiFrom(gain, loss);
  for (let bar = period + 1; bar < bars; bar++) {
    const change = closes[bar] - closes[bar - 1];
    gain = (gain * (period - 1) + (change > 0 ? change : 0)) / period;
    loss = (loss * (period - 1) + (change < 0 ? -change : 0)) / period;
    rsi[bar] = rsiFrom(gain, loss);
  }
  return rsi;
}
