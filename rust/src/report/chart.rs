//! The text-rendered chart of the account value and the market index.
//!
//! The chart is one plot area with two lines in it: the account value of the strategy and the
//! equal-weight market index. The lines are drawn with different box-drawing characters and, if
//! colour is on, in different colours, so they stay apart even without colour.

use crate::domain::Timestamp;
use crate::report::format::compact;

/// The visible width of the chart.
pub const WIDTH: usize = 80;
/// The number of plot rows.
pub const HEIGHT: usize = 12;
/// The width of the axis label column, the separator included.
const LABEL_WIDTH: usize = 8;
/// The number of dates on the date axis.
const DATES: usize = 5;
/// The colour of the strategy line.
const STRATEGY_COLOR: &str = "\x1b[96m";
/// The colour of the market index line.
const INDEX_COLOR: &str = "\x1b[93m";
/// The escape that resets the terminal back to its default colours.
const RESET_COLOR: &str = "\x1b[0m";

/// The options of the chart.
#[derive(Clone, Copy, Debug)]
pub struct ChartOptions {
    /// The visible width of the chart.
    pub width: usize,
    /// The number of plot rows.
    pub height: usize,
    /// Whether the two series are painted in colour.
    pub color: bool,
}

// The default chart is 80 columns wide, 12 rows high and painted in colour.
impl Default for ChartOptions {
    /// The default chart: 80 columns wide, 12 rows high, painted in colour.
    fn default() -> Self {
        Self {
            width: WIDTH,
            height: HEIGHT,
            color: true,
        }
    }
}

/// Which of the two series a piece of the chart belongs to.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Series {
    /// The account value of the strategy.
    Strategy,
    /// The equal-weight market index.
    Index,
}

/// One cell of the chart.
#[derive(Clone, Copy, Debug)]
struct Cell {
    character: char,
    series: Option<Series>,
}

// The helpers of a cell.
impl Cell {
    /// A cell that belongs to the frame or to a label.
    fn plain(character: char) -> Self {
        Self {
            character,
            series: None,
        }
    }
}

/// The characters one series is drawn with.
fn glyphs(series: Series) -> (char, char) {
    match series {
        Series::Strategy => ('─', '│'),
        Series::Index => ('═', '║'),
    }
}

/// Renders the account value and the market index as one chart.
pub fn render(
    equity: &[f64],
    index: &[f64],
    timestamps: &[Timestamp],
    options: &ChartOptions,
) -> Vec<String> {
    let width = options.width.max(LABEL_WIDTH + 2);
    let columns = width - LABEL_WIDTH - 2;
    let rows = options.height.max(1);
    let equity = sample(equity, columns);
    let index = sample(index, columns);
    let (low, high) = bounds(&equity, &index);

    let mut strategy_grid = vec![vec![None; columns]; rows];
    let mut index_grid = vec![vec![None; columns]; rows];
    draw(&equity, &mut strategy_grid, Series::Strategy, low, high);
    draw(&index, &mut index_grid, Series::Index, low, high);

    let mut lines = Vec::with_capacity(rows + 4);
    lines.push(paint(
        &frame(width, '╭', '╮', Some(" equity vs market index ")),
        options.color,
    ));
    for row in 0..rows {
        let label = format!("{:>6.6} ┤", compact(value_at(low, high, row, rows)));
        let mut cells = vec![Cell::plain('│')];
        cells.extend(label.chars().map(Cell::plain));
        for column in 0..columns {
            let cell = strategy_grid[row][column].or(index_grid[row][column]);
            cells.push(cell.unwrap_or(Cell::plain(' ')));
        }
        cells.push(Cell::plain('│'));
        lines.push(paint(&cells, options.color));
    }
    lines.push(paint(&frame(width, '╰', '╯', None), options.color));
    lines.push(axis(timestamps, columns));
    lines.push(legend(options.color));
    lines
}

/// The top or the bottom border of the chart.
fn frame(width: usize, left: char, right: char, title: Option<&str>) -> Vec<Cell> {
    let mut cells = vec![Cell::plain(left)];
    if let Some(title) = title
        && title.len() + 2 <= width - 2
    {
        cells.push(Cell::plain('─'));
        cells.extend(title.chars().map(Cell::plain));
    }
    while cells.len() < width - 1 {
        cells.push(Cell::plain('─'));
    }
    cells.truncate(width - 1);
    cells.push(Cell::plain(right));
    cells
}

/// Reduces a series to one value per column, the last value of every bucket.
fn sample(series: &[f64], columns: usize) -> Vec<f64> {
    if series.is_empty() || columns == 0 {
        return vec![0.0; columns];
    }
    (0..columns)
        .map(|column| {
            let end = (((column + 1) * series.len()) / columns).clamp(1, series.len());
            series[end - 1]
        })
        .collect()
}

/// The lowest and the highest value of the two series.
fn bounds(equity: &[f64], index: &[f64]) -> (f64, f64) {
    let lowest = equity
        .iter()
        .chain(index.iter())
        .copied()
        .fold(f64::INFINITY, f64::min);
    let highest = equity
        .iter()
        .chain(index.iter())
        .copied()
        .fold(f64::NEG_INFINITY, f64::max);
    if !lowest.is_finite() || !highest.is_finite() {
        return (0.0, 1.0);
    }
    if (highest - lowest).abs() < f64::EPSILON {
        (lowest - 1.0, highest + 1.0)
    } else {
        (lowest, highest)
    }
}

/// The value a plot row shows.
fn value_at(low: f64, high: f64, row: usize, rows: usize) -> f64 {
    if rows <= 1 {
        return high;
    }
    high - (high - low) * (row as f64) / ((rows - 1) as f64)
}

/// Draws one series into the plot area.
fn draw(values: &[f64], grid: &mut [Vec<Option<Cell>>], series: Series, low: f64, high: f64) {
    let (horizontal, vertical) = glyphs(series);
    let rows = grid.len();
    let mut previous: Option<usize> = None;
    for (column, &value) in values.iter().enumerate() {
        let row = row_of(value, low, high, rows);
        if let Some(previous_row) = previous {
            let bottom = previous_row.min(row);
            let top = previous_row.max(row);
            for line in grid.iter_mut().take(top).skip(bottom) {
                line[column] = Some(Cell {
                    character: vertical,
                    series: Some(series),
                });
            }
        }
        grid[row][column] = Some(Cell {
            character: horizontal,
            series: Some(series),
        });
        previous = Some(row);
    }
}

/// The plot row a value belongs to.
fn row_of(value: f64, low: f64, high: f64, rows: usize) -> usize {
    if rows <= 1 || !value.is_finite() {
        return 0;
    }
    let position = (high - value) / (high - low) * ((rows - 1) as f64);
    (position.round().max(0.0) as usize).min(rows - 1)
}

/// The date axis below the chart.
fn axis(timestamps: &[Timestamp], columns: usize) -> String {
    let mut cells = vec![Cell::plain(' '); LABEL_WIDTH + 1 + columns];
    if !timestamps.is_empty() && columns > DATES {
        for index in 0..DATES {
            let step = index * (timestamps.len() - 1) / (DATES - 1);
            let date = timestamps[step].date();
            let column = index * (columns - date.len()) / (DATES - 1);
            for (offset, character) in date.chars().enumerate() {
                if column + offset < columns {
                    cells[LABEL_WIDTH + 1 + column + offset] = Cell::plain(character);
                }
            }
        }
    }
    paint(&cells, false)
}

/// The legend below the chart.
fn legend(color: bool) -> String {
    let mut cells = vec![Cell::plain(' '); 2];
    cells.extend("── strategy equity".chars().map(|character| Cell {
        character,
        series: Some(Series::Strategy),
    }));
    cells.push(Cell::plain(' '));
    cells.extend("══ market index".chars().map(|character| Cell {
        character,
        series: Some(Series::Index),
    }));
    paint(&cells, color)
}

/// Turns the cells of one line into text, painting the series in colour.
fn paint(cells: &[Cell], color: bool) -> String {
    let mut out = String::with_capacity(cells.len() + 16);
    let mut current: Option<Series> = None;
    for cell in cells {
        if color && cell.series != current {
            out.push_str(match cell.series {
                Some(Series::Strategy) => STRATEGY_COLOR,
                Some(Series::Index) => INDEX_COLOR,
                None => RESET_COLOR,
            });
            current = cell.series;
        }
        out.push(cell.character);
    }
    if color {
        out.push_str(RESET_COLOR);
    }
    out
}
