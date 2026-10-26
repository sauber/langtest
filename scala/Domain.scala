// Domain types shared by the market-data, simulation, and metrics layers
package langtest

// A single closed trade produced by the simulator
final case class Trade(buyStep: Int, sellStep: Int, entryCash: Double, proceeds: Double)

// Per-coin arrays aligned to the global simulation timeline
final case class CoinData(
    symbol: String,
    closeAt: Array[Double],
    signalAt: Array[Byte],
    strengthAt: Array[Double]
)

// Result of a full simulation run
final case class SimResult(accountValues: Array[Double], trades: Seq[Trade])

// Signal encoding constants
object Signal {
  val Pass: Byte = 0
  val Buy: Byte = 1
  val Sell: Byte = 2
}

// Resolve the shared data directory from either the repo root or the scala/ folder
object DataPaths {
  // Resolve the shared data directory from either the repo root or the scala/ folder
  def dataDir: java.io.File = {
    val candidates = Seq(new java.io.File("data"), new java.io.File("../data"))
    candidates.find(f => f.isDirectory && new java.io.File(f, "meta.json").exists()).getOrElse(new java.io.File("data"))
  }
}