// Hourly simulation loop with single-position enforcement
package langtest

// Run the simulation over the prepared dataset
object Simulator {
  // Fixed simulation parameters
  val InitialCapital: Double = 10000.0
  val FeeMultiplierBuy: Double = 1.001
  val FeeMultiplierSell: Double = 0.999

  // Run the simulation over the prepared dataset
  def simulate(dataset: Dataset): (Array[Double], Seq[Trade]) = {
    val n = dataset.timeline.length
    val accountValues = new Array[Double](n)
    val trades = scala.collection.mutable.ArrayBuffer[Trade]()
    var cash = InitialCapital
    var heldCoin = -1
    var heldQty = 0.0
    var heldEntryCash = 0.0
    var heldBuyStep = 0
    var heldLastClose = 0.0

    var step = 0
    while (step < n) {
      // Rule 2: sell if held coin has a sell signal at this step
      if (heldCoin >= 0) {
        val coin = dataset.coins(heldCoin)
        if (!coin.closeAt(step).isNaN && coin.signalAt(step) == Signal.Sell) {
          val close = coin.closeAt(step)
          val proceeds = heldQty * close * FeeMultiplierSell
          trades += Trade(heldBuyStep, step, heldEntryCash, proceeds)
          cash = proceeds
          heldCoin = -1
          heldQty = 0.0
          heldEntryCash = 0.0
        }
      }

      // Rule 3: buy best coin if none held
      if (heldCoin < 0) {
        val bc = dataset.bestBuy(step)
        if (bc >= 0) {
          val coin = dataset.coins(bc)
          val close = coin.closeAt(step)
          val qty = cash / (close * FeeMultiplierBuy)
          heldCoin = bc
          heldQty = qty
          heldEntryCash = cash
          heldBuyStep = step
          cash = 0.0
          heldLastClose = close
        }
      }

      // Update last known close for the held coin
      if (heldCoin >= 0) {
        val coin = dataset.coins(heldCoin)
        if (!coin.closeAt(step).isNaN) {
          heldLastClose = coin.closeAt(step)
        }
      }

      // Record account value
      if (heldCoin < 0) {
        accountValues(step) = cash
      } else {
        accountValues(step) = cash + heldQty * heldLastClose
      }

      step += 1
    }

    (accountValues, trades.toSeq)
  }
}