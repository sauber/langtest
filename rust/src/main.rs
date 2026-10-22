//! The command line entry point: load the market, run the simulation, print the report.

use std::path::PathBuf;
use std::process::ExitCode;

use langtest::data::loader;
use langtest::metrics::stats;
use langtest::report::{self, chart::ChartOptions};
use langtest::sim::Simulator;
use langtest::strategy::{PERIOD, RsiStrategy};

/// The name of the program.
const PROGRAM: &str = "langtest";

/// The usage text of the program.
const USAGE: &str = "\
usage: langtest [--data-dir <path>] [--no-color]

  --data-dir <path>  the directory that holds the coin CSV files and meta.json (default: data)
  --no-color         draw the chart without colour
  -h, --help         print this text";

/// The options the program was started with.
struct Options {
    /// The directory that holds the coin CSV files and the meta file.
    data_dir: PathBuf,
    /// Whether the chart is painted in colour.
    color: bool,
}

/// Parses the command line arguments.
fn parse_options(arguments: impl Iterator<Item = String>) -> Result<Option<Options>, String> {
    let mut data_dir = PathBuf::from("data");
    let mut color = std::env::var_os("NO_COLOR").is_none();
    let mut arguments = arguments.peekable();

    while let Some(argument) = arguments.next() {
        match argument.as_str() {
            "--data-dir" => {
                let value = arguments.next().ok_or("--data-dir needs a path")?;
                data_dir = PathBuf::from(value);
            }
            "--no-color" => color = false,
            "-h" | "--help" => {
                println!("{USAGE}");
                return Ok(None);
            }
            other => return Err(format!("unknown argument `{other}`")),
        }
    }
    Ok(Some(Options { data_dir, color }))
}

/// Loads the market, runs the simulation and builds the report.
fn evaluate(options: &Options) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let market = loader::load(&options.data_dir)?;
    let strategy = RsiStrategy::new(PERIOD);
    let simulation = Simulator::new(&market, &strategy).run();
    let metrics = stats::compute(&simulation, &market.index);
    let chart = ChartOptions {
        color: options.color,
        ..ChartOptions::default()
    };
    Ok(report::build(
        &market,
        &metrics,
        &simulation.equity,
        simulation.elapsed,
        PERIOD,
        &chart,
    ))
}

/// Runs the program and reports whether it succeeded.
fn main() -> ExitCode {
    let options = match parse_options(std::env::args().skip(1)) {
        Ok(Some(options)) => options,
        Ok(None) => return ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("{PROGRAM}: {message}");
            eprintln!("{USAGE}");
            return ExitCode::FAILURE;
        }
    };
    match evaluate(&options) {
        Ok(lines) => {
            for line in lines {
                println!("{line}");
            }
            ExitCode::SUCCESS
        }
        Err(error) => {
            eprintln!("{PROGRAM}: {error}");
            ExitCode::FAILURE
        }
    }
}
