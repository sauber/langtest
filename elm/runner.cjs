'use strict';

// Node host that adapts files and the monotonic clock to the Elm worker

const fs = require('node:fs');
const path = require('node:path');
const { performance } = require('node:perf_hooks');

// The compiled Elm bundle attaches itself to module.exports.Elm
const Elm = require('./elm.js').Elm;

// Market data lives next to the language folders
const DATA_DIR = path.resolve(__dirname, '..', 'data');

// Read the metadata that describes the dataset and the market index
function readMeta() {
  return JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'meta.json'), 'utf8'));
}

// Extract only the timestamp and close columns from one hourly CSV
function parseCsv(fileName) {
  const text = fs.readFileSync(path.join(DATA_DIR, fileName), 'utf8');
  const lines = text.split('\n');
  const timestamps = [];
  const closes = [];

  for (let i = 1; i < lines.length; i += 1) {
    const line = lines[i];
    if (line.length === 0) continue;

    const firstComma = line.indexOf(',');
    let comma = firstComma;
    for (let field = 0; field < 4; field += 1) {
      comma = line.indexOf(',', comma + 1);
    }
    const closeEnd = line.indexOf(',', comma + 1);

    timestamps.push(Number(line.slice(0, firstComma)));
    closes.push(Number(line.slice(comma + 1, closeEnd)));
  }

  return { ts: timestamps, closes };
}

// Load every coin and keep symbols alphabetically ordered for tie-breaking
function readMarket(meta) {
  return meta.coins
    .map((coin) => ({ symbol: coin.symbol, ...parseCsv(coin.file) }))
    .sort((left, right) => (left.symbol < right.symbol ? -1 : left.symbol > right.symbol ? 1 : 0));
}

// Boot the worker, time only the simulation port call, then ask for the report
function main() {
  const meta = readMeta();
  const coins = readMarket(meta);

  const app = Elm.Main.init();

  const guard = setTimeout(() => {
    process.stderr.write('timed out waiting for the Elm report\n');
    process.exit(1);
  }, 120000);

  app.ports.output.subscribe((text) => {
    clearTimeout(guard);
    process.stdout.write(`${text}\n`);
  });

  app.ports.dataset.send({ coins, index: meta.marketIndex.values });

  const startedAt = performance.now();
  app.ports.run.send(0);
  const seconds = (performance.now() - startedAt) / 1000;

  app.ports.simTime.send(seconds);
}

main();
