import React, { useEffect, useState } from "react";
import {
  LineChart, Line, XAxis, YAxis, Tooltip,
  Legend, ResponsiveContainer, CartesianGrid,
} from "recharts";
import { BandHistory } from "../hooks/useWebSocket";

interface Props {
  historyRef: React.MutableRefObject<BandHistory[]>;
}

const LINES = [
  { key: "alpha", name: "α Alpha", color: "hsl(187 80% 55%)" },
  { key: "beta",  name: "β Beta",  color: "hsl(310 60% 55%)" },
  { key: "theta", name: "θ Theta", color: "hsl(270 60% 55%)" },
  { key: "gamma", name: "γ Gamma", color: "hsl(45 90% 60%)"  },
  { key: "delta", name: "δ Delta", color: "hsl(220 70% 55%)" },
];

export default function EEGChart({ historyRef }: Props) {
  const [data, setData] = useState<BandHistory[]>([]);

  // Pull a fresh snapshot from the ref at 10 Hz
  useEffect(() => {
    const id = setInterval(() => {
      if (historyRef.current.length > 0) {
        setData([...historyRef.current]);
      }
    }, 100);
    return () => clearInterval(id);
  }, [historyRef]);

  const isEmpty = data.length === 0;

  return (
    <div className="glass-card p-5 flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <p className="text-xs font-semibold tracking-widest text-muted-foreground uppercase">
          EEG Band Power — Live
        </p>
        {isEmpty && (
          <span className="mono text-[10px] text-muted-foreground animate-pulse">
            Waiting for signal…
          </span>
        )}
      </div>

      <div className="relative">
        {/* Grid backdrop */}
        <svg
          className="absolute inset-0 w-full h-full opacity-[0.04] pointer-events-none"
          aria-hidden
        >
          <defs>
            <pattern id="egrid" width="20" height="20" patternUnits="userSpaceOnUse">
              <path d="M 20 0 L 0 0 0 20" fill="none" stroke="white" strokeWidth="0.5" />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#egrid)" />
        </svg>

        <ResponsiveContainer width="100%" height={200}>
          <LineChart
            data={data}
            margin={{ top: 4, right: 4, left: -20, bottom: 0 }}
          >
            <CartesianGrid strokeDasharray="3 3" stroke="hsl(230 15% 18%)" />
            <XAxis dataKey="t" hide />
            <YAxis
              domain={[0, 1]}
              tick={{ fill: "hsl(220 15% 40%)", fontSize: 10, fontFamily: "IBM Plex Mono" }}
            />
            <Tooltip
              contentStyle={{
                background: "hsl(230 20% 11%)",
                border: "1px solid hsl(230 15% 18%)",
                borderRadius: 8,
                fontFamily: "IBM Plex Mono",
                fontSize: 11,
              }}
              formatter={(v: number) => v.toFixed(3)}
              labelFormatter={() => ""}
            />
            <Legend
              wrapperStyle={{ fontSize: 11, fontFamily: "IBM Plex Mono", paddingTop: 8 }}
            />
            {LINES.map(({ key, name, color }) => (
              <Line
                key={key}
                type="monotone"
                dataKey={key}
                name={name}
                stroke={color}
                dot={false}
                strokeWidth={2}
                isAnimationActive={false}
              />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
