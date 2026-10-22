//! The CSV reader: the open time and the close price of every row.

use langtest::data::csv::{self, CsvError};

/// The header every coin file starts with.
const HEADER: &str = "timestamp,datetime,open,high,low,close,volume,turnover\n";

/// Builds a coin file from its rows.
fn file(rows: &str) -> Vec<u8> {
    format!("{HEADER}{rows}").into_bytes()
}

/// The open time and the close price of every row are read.
#[test]
fn the_open_time_and_the_close_price_are_read() {
    let bytes = file("1507089600,2017-10-04T00:00:00Z,1.0,2.0,0.5,1.5,10,15\n");
    let bars = csv::parse_bars(&bytes).expect("the file is well formed");
    assert_eq!(bars.len(), 1);
    assert_eq!(bars[0].timestamp.0, 1_507_089_600);
    assert_eq!(bars[0].close.get(), 1.5);
}

/// Every row of a file is read.
#[test]
fn every_row_is_read() {
    let bytes = file(
        "1507089600,2017-10-04T00:00:00Z,1.0,2.0,0.5,1.5,10,15\n\
         1507093200,2017-10-04T01:00:00Z,1.5,2.5,1.0,2.0,20,30\n",
    );
    let bars = csv::parse_bars(&bytes).expect("the file is well formed");
    assert_eq!(bars.len(), 2);
    assert_eq!(bars[1].timestamp.0, 1_507_093_200);
    assert_eq!(bars[1].close.get(), 2.0);
}

/// A file that ends with a line break does not add a row.
#[test]
fn a_trailing_line_break_adds_no_row() {
    let bytes = file("1507089600,2017-10-04T00:00:00Z,1.0,2.0,0.5,1.5,10,15\n");
    let bars = csv::parse_bars(&bytes).expect("the file is well formed");
    assert_eq!(bars.len(), 1);
}

/// A row with too few columns is refused.
#[test]
fn a_row_without_the_close_column_is_refused() {
    let bytes = file("1507089600,2017-10-04T00:00:00Z,1.0,2.0\n");
    let error = csv::parse_bars(&bytes).expect_err("the row is too short");
    assert!(matches!(
        error,
        CsvError::MissingColumn { line: 2, column: 4 }
    ));
}

/// A row whose close is not a number is refused.
#[test]
fn a_row_with_a_bad_close_price_is_refused() {
    let bytes = file("1507089600,2017-10-04T00:00:00Z,1.0,2.0,0.5,x,10,15\n");
    let error = csv::parse_bars(&bytes).expect_err("the close is not a number");
    assert!(matches!(error, CsvError::BadClose { line: 2 }));
}

/// A file without the close column in its header is refused.
#[test]
fn a_file_without_the_expected_header_is_refused() {
    let bytes = b"a,b,c\n1,2,3\n".to_vec();
    let error = csv::parse_bars(&bytes).expect_err("the header is wrong");
    assert!(matches!(error, CsvError::MissingColumn { line: 1, .. }));
}
