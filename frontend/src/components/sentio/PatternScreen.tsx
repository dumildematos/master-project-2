import { motion } from "framer-motion";
import { Download, RefreshCw, Share2, Palette } from "lucide-react";
import { useEffect, useRef, useState } from "react";

const emotionPalettes = [
  { name: "Calm", colors: ["#3dd8e0", "#7b61ff", "#1a1a3e"] },
  { name: "Focused", colors: ["#4169E1", "#7b61ff", "#0d1b2a"] },
  { name: "Excited", colors: ["#e040a0", "#ff6b6b", "#1a0a2e"] },
  { name: "Relaxed", colors: ["#7b61ff", "#3dd8e0", "#0a1628"] },
];

interface Props {
  onNewSession: () => void;
}

const PatternScreen = ({ onNewSession }: Props) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [paletteIdx, setPaletteIdx] = useState(0);
  const palette = emotionPalettes[paletteIdx];
  const animRef = useRef<number>(0);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d")!;
    const w = (canvas.width = 600);
    const h = (canvas.height = 600);

    let t = 0;
    const draw = () => {
      t += 0.005;
      ctx.fillStyle = palette.colors[2];
      ctx.fillRect(0, 0, w, h);

      for (let i = 0; i < 12; i++) {
        for (let j = 0; j < 12; j++) {
          const x = (i / 12) * w + Math.sin(t + j * 0.5) * 15;
          const y = (j / 12) * h + Math.cos(t + i * 0.3) * 15;
          const size = 20 + Math.sin(t * 2 + i + j) * 10;
          const colorIdx = (i + j) % 2;

          ctx.beginPath();
          if ((i + j) % 3 === 0) {
            // Circles
            ctx.arc(x + 25, y + 25, size / 2, 0, Math.PI * 2);
          } else if ((i + j) % 3 === 1) {
            // Flowing curves
            ctx.moveTo(x, y + size);
            ctx.bezierCurveTo(x + size * 0.3, y - size * 0.2, x + size * 0.7, y + size * 1.2, x + size, y);
          } else {
            // Diamond
            ctx.moveTo(x + size / 2, y);
            ctx.lineTo(x + size, y + size / 2);
            ctx.lineTo(x + size / 2, y + size);
            ctx.lineTo(x, y + size / 2);
            ctx.closePath();
          }

          ctx.strokeStyle = palette.colors[colorIdx] + "80";
          ctx.lineWidth = 1.5;
          ctx.stroke();

          // Fill with transparency
          ctx.fillStyle = palette.colors[colorIdx] + "15";
          ctx.fill();
        }
      }

      // Overlay gradient
      const grad = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w * 0.6);
      grad.addColorStop(0, "transparent");
      grad.addColorStop(1, palette.colors[2] + "80");
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, w, h);

      animRef.current = requestAnimationFrame(draw);
    };

    draw();
    return () => cancelAnimationFrame(animRef.current);
  }, [palette]);

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.5 }}
      className="min-h-screen p-4 md:p-8 flex flex-col items-center"
    >
      {/* Header */}
      <div className="w-full max-w-4xl flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-bold glow-text-cyan">Generated Pattern</h1>
          <p className="text-sm text-muted-foreground font-mono mt-1">
            Emotion: <span style={{ color: palette.colors[0] }}>{palette.name}</span>
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Palette className="w-4 h-4 text-muted-foreground" />
          <div className="flex gap-1.5">
            {palette.colors.slice(0, 2).map((c, i) => (
              <div key={i} className="w-5 h-5 rounded-full border border-border/40" style={{ background: c }} />
            ))}
          </div>
        </div>
      </div>

      {/* Canvas */}
      <motion.div
        initial={{ scale: 0.95, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ delay: 0.2, duration: 0.6 }}
        className="glass-card gradient-border p-3 mb-8"
      >
        <canvas
          ref={canvasRef}
          className="rounded-xl w-full max-w-[500px] aspect-square"
          style={{ imageRendering: "auto" }}
        />
      </motion.div>

      {/* Emotion palette selector */}
      <div className="flex gap-3 mb-8">
        {emotionPalettes.map((p, i) => (
          <button
            key={p.name}
            onClick={() => setPaletteIdx(i)}
            className={`px-4 py-2 rounded-xl text-sm font-mono transition-all border ${
              i === paletteIdx
                ? "border-primary/50 bg-primary/10 text-primary"
                : "border-border/30 text-muted-foreground hover:border-border/60"
            }`}
          >
            {p.name}
          </button>
        ))}
      </div>

      {/* Actions */}
      <div className="flex gap-3">
        <button className="glass-card px-5 py-3 rounded-xl text-sm font-medium flex items-center gap-2 text-foreground hover:bg-muted/30 transition-all">
          <Download className="w-4 h-4" />
          Save Pattern
        </button>
        <button className="glass-card px-5 py-3 rounded-xl text-sm font-medium flex items-center gap-2 text-foreground hover:bg-muted/30 transition-all">
          <Share2 className="w-4 h-4" />
          Export Design
        </button>
        <button
          onClick={onNewSession}
          className="px-5 py-3 rounded-xl text-sm font-medium flex items-center gap-2 bg-primary text-primary-foreground hover:shadow-[0_0_30px_hsl(187_80%_55%/0.3)] transition-all"
        >
          <RefreshCw className="w-4 h-4" />
          New Session
        </button>
      </div>
    </motion.div>
  );
};

export default PatternScreen;
