//> using test.dep "org.scalameta::munit::1.3.6"
// Unit tests for simulator rules
package langtest

class SimTest extends munit.FunSuite {
  private def mkCoin(symbol: String, close: Array[Double], sig: Array[Byte], str: Array[Double]): CoinData =
    CoinData(symbol, close, sig, str)

  test("best-buy ranking picks highest strength") {
    val n = 1
    val a = mkCoin("A", Array(100.0), Array(Signal.Buy), Array(5.0))
    val b = mkCoin("B", Array(100.0), Array(Signal.Buy), Array(10.0))
    val bb = MarketData.computeBestBuy(Array(a, b), n)
    assertEquals(bb(0), 1)
  }

  test("best-buy tie breaks alphabetically") {
    val n = 1
    val a = mkCoin("A", Array(100.0), Array(Signal.Buy), Array(5.0))
    val b = mkCoin("B", Array(100.0), Array(Signal.Buy), Array(5.0))
    val bb = MarketData.computeBestBuy(Array(a, b), n)
    assertEquals(bb(0), 0)
  }

  test("fees applied on a single buy/sell") {
    val n = 2
    val close = Array(100.0, 110.0)
    val sig = Array(Signal.Buy, Signal.Sell)
    val str = Array(10.0, 0.0)
    val coin = mkCoin("A", close, sig, str)
    val dataset = Dataset(Array(0L, 1L), Array(coin), Array(10000.0, 10000.0), MarketData.computeBestBuy(Array(coin), n))
    val (vals, trades) = Simulator.simulate(dataset)
    assertEquals(trades.length, 1)
    val expectedQty = 10000.0 / (100.0 * 1.001)
    val expectedProceeds = expectedQty * 110.0 * 0.999
    assert(math.abs(vals(1) - expectedProceeds) < 1e-6)
  }

  test("gap carries position and uses last known close") {
    val n = 3
    val close = Array(100.0, Double.NaN, 105.0)
    val sig = Array(Signal.Buy, Signal.Pass, Signal.Pass)
    val str = Array(10.0, 0.0, 0.0)
    val coin = mkCoin("A", close, sig, str)
    val dataset = Dataset(Array(0L, 1L, 2L), Array(coin), Array(10000.0, 10000.0, 10000.0), MarketData.computeBestBuy(Array(coin), n))
    val (vals, trades) = Simulator.simulate(dataset)
    // No sell signal, so still holding; value at gap step uses last close 100
    assert(math.abs(vals(1) - vals(0)) < 1e-6)
  }
}