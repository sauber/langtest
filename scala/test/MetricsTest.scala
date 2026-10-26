//> using test.dep "org.scalameta::munit::1.3.6"
// Unit tests for performance metrics
package langtest

class MetricsTest extends munit.FunSuite {
  test("Sharpe ratio on constant returns is N/A (std 0)") {
    val vals = Array(100.0, 110.0, 121.0) // constant 10% returns
    val s = Metrics.sharpe(vals)
    assert(s.isEmpty)
  }

  test("Sharpe ratio computes finite value") {
    val vals = Array(100.0, 105.0, 100.0, 110.0)
    val s = Metrics.sharpe(vals)
    assert(s.isDefined)
  }

  test("win/loss counts correctly") {
    val trades = Seq(
      Trade(0, 1, 100.0, 110.0), // win
      Trade(2, 3, 100.0, 90.0),  // loss
      Trade(4, 5, 100.0, 100.0)  // zero, excluded
    )
    val (w, l) = Metrics.winLoss(trades)
    assertEquals(w, 1)
    assertEquals(l, 1)
  }

  test("average gain") {
    val trades = Seq(
      Trade(0, 1, 100.0, 110.0),
      Trade(2, 3, 100.0, 90.0)
    )
    val g = Metrics.avgGain(trades)
    assert(math.abs(g - 0.0) < 1e-9) // (0.1 + -0.1)/2
  }

  test("average holding time") {
    val trades = Seq(
      Trade(0, 3, 100.0, 110.0),
      Trade(4, 6, 100.0, 90.0)
    )
    val h = Metrics.avgHoldingSteps(trades)
    assertEquals(h, 2.5)
  }
}