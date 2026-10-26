// Entry point: load data, run simulation, print metrics and chart
package langtest

// Entry point for the evaluation
@main def main(): Unit = {
  val out = new java.io.PrintWriter(new java.io.OutputStreamWriter(System.out, java.nio.charset.StandardCharsets.UTF_8), true)
  // Load market data (excluded from timing)
  val dataset = MarketData.load()

  // Time only the hourly simulation loop
  val t0 = System.nanoTime()
  val (accountValues, trades) = Simulator.simulate(dataset)
  val t1 = System.nanoTime()
  val simSeconds = (t1 - t0) / 1e9

  // Compute performance metrics (excluded from timing)
  val strategyFinal = accountValues(accountValues.length - 1)
  val indexFinal = dataset.marketIndex(dataset.marketIndex.length - 1)
  val ratio = strategyFinal / indexFinal
  val sharpe = Metrics.sharpe(accountValues)
  val (wins, losses) = Metrics.winLoss(trades)
  val winLossRatio = if (losses == 0) Double.PositiveInfinity else wins.toDouble / losses.toDouble
  val avgGain = Metrics.avgGain(trades)
  val avgHold = Metrics.avgHoldingSteps(trades)

  // Print metrics
  out.println(f"End vs market index: $ratio%.4f")
  out.println(sharpe match {
    case Some(v) => f"Sharpe ratio: $v%.4f"
    case None => "Sharpe ratio: N/A"
  })
  out.println(if (losses == 0) "Win/loss ratio: inf" else f"Win/loss ratio: $winLossRatio%.4f")
  out.println(f"Avg gain per trade: $avgGain%.4f")
  out.println(f"Avg holding time: $avgHold%.2f h")
  out.println(f"sim time: $simSeconds%.3f s")

  // Render and print the chart
  out.println("Account value vs market index")
  val chartLines = Chart.render(accountValues, dataset.marketIndex, 72, 16)
  chartLines.foreach(out.println)
  out.println("cyan: account value  magenta: market index")
  out.flush()
}