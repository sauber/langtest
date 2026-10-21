import type {
  BarHistory,
  CoinSeries,
  Market,
  SignalCode,
  SignalSeries,
} from "../src/domain/types.ts";
import { Signal } from "../src/domain/types.ts";
import { alignToTimeline, buildTimeline } from "../src/data/loader.ts";
import type { Strategy } from "../src/strategy/strategy.ts";

// The scripted signals of one coin, given per bar index.
export interface Script {
  readonly signal: readonly SignalCode[];
  readonly strength?: readonly number[];
}

// Builds a synthetic market from compact bar lists so the tests need no files on disk.
export function marketOf(
  specs: readonly { symbol: string; bars: readonly (readonly [number, number])[] }[],
): Market {
  const histories: BarHistory[] = specs.map((spec) => ({
    symbol: spec.symbol,
    timestamps: spec.bars.map(([timestamp]) => timestamp),
    closes: spec.bars.map(([, close]) => close),
  }));
  const timeline = buildTimeline(histories);
  return { timeline, coins: alignToTimeline(timeline, histories) };
}

// A strategy stub that replays scripted signals so simulator rules can be tested in isolation.
export class ScriptedStrategy implements Strategy {
  readonly name = "scripted";

  constructor(private readonly script: Readonly<Record<string, Script>>) {}

  // Emits the scripted signals of one coin, defaulting to pass everywhere else.
  evaluate(coin: CoinSeries): SignalSeries {
    const spec = this.script[coin.symbol];
    const bars = coin.closes.length;
    const signal = new Int8Array(bars);
    const strength = new Float64Array(bars);
    for (let bar = 0; bar < bars; bar++) {
      signal[bar] = spec?.signal[bar] ?? Signal.Pass;
      strength[bar] = spec?.strength?.[bar] ?? 0;
    }
    return { signal, strength, rsi: new Float64Array(bars) };
  }
}
