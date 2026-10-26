// Performance metrics for the completed simulation
package langtest

// Compute Sharpe ratio from an account-value series
object Metrics {
  // Compute Sharpe ratio from an account-value series
  def sharpe(values: Array[Double]): Option[Double] = {
    val m = values.length - 1
    if (m < 2) return None
    val returns = new Array[Double](m)
    var i = 0
    while (i < m) {
      returns(i) = values(i + 1) / values(i) - 1.0
      i += 1
    }
    var sum = 0.0
    i = 0
    while (i < m) { sum += returns(i); i += 1 }
    val mean = sum / m
    var sq = 0.0
    i = 0
    while (i < m) {
      val d = returns(i) - mean
      sq += d * d
      i += 1
    }
    val std = math.sqrt(sq / (m - 1))
    if (std == 0.0) None else Some(mean / std * math.sqrt(8760.0))
  }

  // Count winning and losing closed trades
  def winLoss(trades: Seq[Trade]): (Int, Int) = {
    var wins = 0
    var losses = 0
    trades.foreach { t =>
      val r = t.proceeds / t.entryCash - 1.0
      if (r > 0.0) wins += 1
      else if (r < 0.0) losses += 1
    }
    (wins, losses)
  }

  // Mean net return across all closed trades
  def avgGain(trades: Seq[Trade]): Double = {
    if (trades.isEmpty) 0.0
    else {
      var sum = 0.0
      trades.foreach(t => sum += t.proceeds / t.entryCash - 1.0)
      sum / trades.length
    }
  }

  // Mean holding time in simulation steps
  def avgHoldingSteps(trades: Seq[Trade]): Double = {
    if (trades.isEmpty) 0.0
    else {
      var sum = 0.0
      trades.foreach(t => sum += (t.sellStep - t.buyStep).toDouble)
      sum / trades.length
    }
  }
}