//> using test.dep "org.scalameta::munit::1.3.6"
// Unit tests for RSI calculation
package langtest

class RsiTest extends munit.FunSuite {
  test("RSI is 100 for strictly increasing closes") {
    val closes = (1 to 20).map(_.toDouble).toArray
    val r = Rsi.rsi(closes)
    (0 until Rsi.Period).foreach(i => assert(r(i).isNaN))
    assertEquals(r(Rsi.Period), 100.0)
  }

  test("RSI is 0 for strictly decreasing closes") {
    val closes = (20 to 1 by -1).map(_.toDouble).toArray
    val r = Rsi.rsi(closes)
    assertEquals(r(Rsi.Period), 0.0)
  }

  test("RSI has NaN before Period bars") {
    val closes = Array.fill(10)(100.0)
    val r = Rsi.rsi(closes)
    assert(r.forall(_.isNaN))
  }
}