// CSV parsing utilities for market data files
package langtest

import scala.io.Source

// Raw coin series parsed from a CSV file
final case class RawCoin(symbol: String, timestamps: Array[Long], closes: Array[Double])

// Parse a single coin CSV file into a RawCoin
object Csv {
  def readCoin(file: java.io.File): RawCoin = {
    val symbol = file.getName.stripSuffix(".csv")
    val source = Source.fromFile(file)
    val rows = try {
      source.getLines().drop(1).filter(_.nonEmpty).map(parseRow).toArray
    } finally source.close()
    RawCoin(symbol, rows.map(_._1), rows.map(_._2))
  }

  // Parse one CSV row, extracting timestamp and close price
  private def parseRow(line: String): (Long, Double) = {
    val cols = line.split(",", -1)
    (cols(0).trim.toLong, cols(5).trim.toDouble)
  }
}