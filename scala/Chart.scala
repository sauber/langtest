// Text-based line chart rendering for terminal output
package langtest

// Render two series as a colored line chart
object Chart {
  // Render two series as a colored line chart
  def render(account: Array[Double], market: Array[Double], width: Int, height: Int): Seq[String] = {
    // Downsample each series to the chart width
    val accSample = downsample(account, width)
    val mktSample = downsample(market, width)

    val minV = math.min(accSample.min, mktSample.min)
    val maxV = math.max(accSample.max, mktSample.max)

    def toRow(v: Double): Int = {
      if (maxV == minV) height / 2
      else {
        val r = (height - 1) - math.round((v - minV) / (maxV - minV) * (height - 1)).toInt
        math.max(0, math.min(height - 1, r))
      }
    }

    val accRows = accSample.map(toRow)
    val mktRows = mktSample.map(toRow)

    val grid = Array.fill(height, width)(' ')
    val color = Array.fill(height, width)(0)

    // Write a character into the chart grid
    def set(x: Int, y: Int, ch: Char, cid: Int): Unit = {
      if (x >= 0 && x < width && y >= 0 && y < height) {
        grid(y)(x) = ch
        color(y)(x) = cid
      }
    }

    // Draw a series using soft line-drawing characters
    def draw(rows: Array[Int], cid: Int): Unit = {
      var i = 0
      while (i < width - 1) {
        val y0 = rows(i)
        val y1 = rows(i + 1)
        if (y0 == y1) {
          set(i, y0, '\u2500', cid)
        } else if (y0 < y1) {
          set(i, y0, '\u256e', cid)
          var y = y0 + 1
          while (y < y1) { set(i, y, '\u2502', cid); y += 1 }
          set(i, y1, '\u2570', cid)
        } else {
          set(i, y0, '\u256f', cid)
          var y = y1 + 1
          while (y < y0) { set(i, y, '\u2502', cid); y += 1 }
          set(i, y1, '\u256d', cid)
        }
        i += 1
      }
      set(width - 1, rows(width - 1), '\u2500', cid)
    }

    draw(accRows, 1)
    draw(mktRows, 2)

    // Render grid with per-cell color
    val codes = Array("", "\u001b[36m", "\u001b[35m")
    val lines = scala.collection.mutable.ArrayBuffer[String]()
    var y = 0
    while (y < height) {
      val sb = new StringBuilder
      var x = 0
      var runColor = 0
      while (x < width) {
        val c = color(y)(x)
        if (c != runColor) {
          if (runColor != 0) sb.append("\u001b[0m")
          if (c != 0) sb.append(codes(c))
          runColor = c
        }
        sb.append(grid(y)(x))
        x += 1
      }
      if (runColor != 0) sb.append("\u001b[0m")
      lines += sb.toString
      y += 1
    }
    lines.toSeq
  }

  // Downsample a series to the requested number of points
  private def downsample(series: Array[Double], width: Int): Array[Double] = {
    val n = series.length
    val out = new Array[Double](width)
    var i = 0
    while (i < width) {
      val idx = if (width == 1) 0 else i * (n - 1) / (width - 1)
      out(i) = series(idx)
      i += 1
    }
    out
  }
}