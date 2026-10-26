// Build the global timeline and per-coin signal arrays
package langtest

import scala.collection.mutable

// Loaded dataset ready for simulation
final case class Dataset(
    timeline: Array[Long],
    coins: Array[CoinData],
    marketIndex: Array[Double],
    bestBuy: Array[Int]
)

// Load all coins, build timeline, precompute signals and best-buy ranking
object MarketData {
  // Load all coins, build timeline, precompute signals and best-buy ranking
  def load(): Dataset = {
    val dir = DataPaths.dataDir
    val files = dir.listFiles().filter(f => f.getName.endsWith(".csv")).sorted
    val rawCoins = files.map(Csv.readCoin).sortBy(_.symbol)

    // Build sorted unique timeline from all timestamps
    val allTs = mutable.ArrayBuffer[Long]()
    rawCoins.foreach(c => allTs ++= c.timestamps)
    val timeline = allTs.toArray.sorted.distinct

    // Map timestamp to step index for constant-time lookup
    val tsIndex = mutable.HashMap[Long, Int]()
    var si = 0
    while (si < timeline.length) {
      tsIndex(timeline(si)) = si
      si += 1
    }

    // Build per-coin arrays aligned to the timeline
    val coins = rawCoins.map { rc =>
      val n = timeline.length
      val closeAt = Array.fill(n)(Double.NaN)
      val signalAt = new Array[Byte](n)
      val strengthAt = Array.fill(n)(Double.NaN)
      val rsiVals = Rsi.rsi(rc.closes)
      var bi = 0
      while (bi < rc.timestamps.length) {
        val step = tsIndex(rc.timestamps(bi))
        closeAt(step) = rc.closes(bi)
        val r = rsiVals(bi)
        if (!r.isNaN) {
          if (r <= 30.0) {
            signalAt(step) = Signal.Buy
            strengthAt(step) = 30.0 - r
          } else if (r >= 70.0) {
            signalAt(step) = Signal.Sell
          }
        }
        bi += 1
      }
      CoinData(rc.symbol, closeAt, signalAt, strengthAt)
    }

    // Read market index values from meta.json
    val metaText = scala.io.Source.fromFile(new java.io.File(dir, "meta.json")).mkString
    val marketIndex = parseMarketIndex(metaText)

    // Precompute best buy coin index for each step (alphabetical tie-break via sorted coins)
    val bestBuy = new Array[Int](timeline.length)
    var step = 0
    while (step < timeline.length) {
      var bestIdx = -1
      var bestStrength = Double.NegativeInfinity
      var ci = 0
      while (ci < coins.length) {
        if (coins(ci).signalAt(step) == Signal.Buy) {
          val st = coins(ci).strengthAt(step)
          if (st > bestStrength) {
            bestStrength = st
            bestIdx = ci
          }
        }
        ci += 1
      }
      bestBuy(step) = bestIdx
      step += 1
    }

    Dataset(timeline, coins, marketIndex, bestBuy)
  }

  // Compute best-buy coin index per step for arbitrary coin arrays (used by tests)
  def computeBestBuy(coins: Array[CoinData], n: Int): Array[Int] = {
    val bestBuy = new Array[Int](n)
    var step = 0
    while (step < n) {
      var bestIdx = -1
      var bestStrength = Double.NegativeInfinity
      var ci = 0
      while (ci < coins.length) {
        if (coins(ci).signalAt(step) == Signal.Buy) {
          val st = coins(ci).strengthAt(step)
          if (st > bestStrength) {
            bestStrength = st
            bestIdx = ci
          }
        }
        ci += 1
      }
      bestBuy(step) = bestIdx
      step += 1
    }
    bestBuy
  }

  // Extract the marketIndex.values array from meta.json text
  private def parseMarketIndex(text: String): Array[Double] = {
    val regex = "\"values\"\\s*:\\s*\\[([^\\]]*)\\]".r
    val m = regex.findFirstMatchIn(text).getOrElse(throw new RuntimeException("marketIndex.values not found"))
    m.group(1).split(",").map(_.trim).filter(_.nonEmpty).map(_.toDouble)
  }
}