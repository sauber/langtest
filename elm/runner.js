#!/usr/bin/env node

// Node host of the Elm evaluator: it reads the market data files and drives the compiled Elm program.

const fs = require("fs");
const path = require("path");

// Resolves the directory that holds the market data files.
function resolveDataDir(argv) {
  const flag = argv.find((argument) => argument.startsWith("--data="));

  if (flag) {
    return path.resolve(flag.slice("--data=".length));
  }

  return path.resolve(__dirname, "..", "data");
}

// Lists the market data files of a directory in alphabetical order.
function listDataFiles(dataDir) {
  return fs
    .readdirSync(dataDir)
    .filter((name) => name.endsWith(".csv"))
    .sort();
}

// Reads one market data file and hands it to the Elm program.
function loadFile(app, dataDir, name) {
  const text = fs.readFileSync(path.join(dataDir, name), "utf8");
  app.ports.fileIn.send(text);
}

// Starts the Elm program and connects it to the file system and the clock.
function main() {
  const dataDir = resolveDataDir(process.argv.slice(2));

  if (!fs.existsSync(dataDir)) {
    process.stderr.write(`data directory not found: ${dataDir}\n`);
    process.exit(1);
  }

  const { Elm } = require("./elm.js");
  const app = Elm.Main.init({ node: true });
  const files = listDataFiles(dataDir);

  app.ports.out.subscribe((report) => process.stdout.write(`${report}\n`));

  app.ports.requestClock.subscribe(() => {
    const timestamp = performance.now() / 1000;
    app.ports.clockIn.send(timestamp);
  });

  app.ports.requestFile.subscribe((name) => loadFile(app, dataDir, name));

  app.ports.namesIn.send(files);
}

main();
