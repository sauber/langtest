// Relative Strength Index using Wilder's smoothing
package langtest

// Compute RSI for a sequence of closing prices
object Rsi {
  val Period: Int = 14

  def rsi(closes: Array[Double]): Array[Double] = {
    val n = closes.length
    val out = Array.fill(n)(Double.NaN)
    if (n <= Period) return out

    // Initial averages over the first Period changes
    var avgGain = 0.0
    var avgLoss = 0.0
    var i = 1
    while (i <= Period) {
      val change = closes(i) - closes(i - 1)
      if (change > 0) avgGain += change else avgLoss -= change
      i += 1
    }
    avgGain /= Period
    avgLoss /= Period
    out(Period) = rsiFromAverages(avgGain, avgLoss)

    // Wilder smoothing for subsequent bars
    i = Period + 1
    while (i < n) {
      val change = closes(i) - closes(i - 1)
      val gain = if (change > 0) change else 0.0
      val loss = if (change < 0) -change else 0.0
      avgGain = (avgGain * (Period - 1) + gain) / Period
      avgLoss = (avgLoss * (Period - 1) + loss) / Period
      out(i) = rsiFromAverages(avgGain, avgLoss)
      i += 1
    }
    out
  }

  // Convert smoothed gain/loss averages into an RSI value
  private def rsiFromAverages(avgGain: Double, avgLoss: Double): Double = {
    if (avgLoss == 0.0) 100.0
    else 100.0 - 100.0 / (1.0 + avgGain / avgLoss)
  }
}