import React, { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { WifiOff, RefreshCw, X } from "lucide-react";

// ---------------------------------------------------------------------------
// Reconnect countdown — counts down from 10 and auto-resets
// ---------------------------------------------------------------------------
function useCountdown(active: boolean, onReset: () => void) {
  const [count, setCount] = useState(10);

  useEffect(() => {
    if (!active) { setCount(10); return; }
    const id = setInterval(() => {
      setCount(prev => {
        if (prev <= 1) { onReset(); return 10; }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(id);
  }, [active, onReset]);

  return count;
}

// ---------------------------------------------------------------------------
// Pulsing signal-bars visualisation (flat/dead while disconnected)
// ---------------------------------------------------------------------------
function DeadBars() {
  const hues = [187, 310, 270, 45, 220];
  return (
    <div className="flex items-end gap-1.5 h-7">
      {hues.map((h, i) => (
        <motion.div
          key={i}
          className="w-2.5 rounded-sm"
          style={{ background: `hsl(${h}, 40%, 22%)` }}
          animate={{ height: [4, 4 + Math.random() * 3, 4] }}
          transition={{ duration: 1.4, repeat: Infinity, delay: i * 0.18, ease: "easeInOut" }}
        />
      ))}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Reconnect toast
// ---------------------------------------------------------------------------
export function ReconnectToast({ show }: { show: boolean }) {
  return (
    <AnimatePresence>
      {show && (
        <motion.div
          key="reconnect-toast"
          initial={{ opacity: 0, y: 16, x: "-50%" }}
          animate={{ opacity: 1, y: 0,  x: "-50%" }}
          exit={{   opacity: 0, y: 16,  x: "-50%" }}
          transition={{ type: "spring", stiffness: 400, damping: 28 }}
          className="fixed bottom-12 left-1/2 z-50 flex items-center gap-2.5
            px-5 py-2.5 rounded-full border border-green-500/30
            bg-green-950/90 backdrop-blur-xl shadow-lg"
        >
          <motion.div
            className="w-2 h-2 rounded-full bg-green-400"
            animate={{ opacity: [0.4, 1, 0.4] }}
            transition={{ duration: 1.2, repeat: Infinity }}
          />
          <span className="font-mono text-[10px] tracking-widest text-green-400 font-medium">
            MUSE 2 RECONNECTED
          </span>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

// ---------------------------------------------------------------------------
// Main modal
// ---------------------------------------------------------------------------
interface Props {
  isOpen:   boolean;
  onDismiss:() => void;
}

export default function DisconnectModal({ isOpen, onDismiss }: Props) {
  const countdown = useCountdown(isOpen, () => {/* auto-retry no-op — state drives recovery */});

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          key="disconnect-overlay"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{   opacity: 0 }}
          transition={{ duration: 0.35 }}
          className="fixed inset-0 z-50 flex items-center justify-center p-6"
        >
          {/* Backdrop */}
          <motion.div
            className="absolute inset-0"
            style={{
              background: "radial-gradient(ellipse at 50% 44%, rgba(0,0,0,0.25) 0%, rgba(0,0,0,0.85) 100%)",
              backdropFilter: "blur(6px)",
            }}
          />

          {/* Card */}
          <motion.div
            initial={{ scale: 0.94, y: 16, opacity: 0 }}
            animate={{ scale: 1,    y: 0,  opacity: 1 }}
            exit={{   scale: 0.94, y: 16,  opacity: 0 }}
            transition={{ type: "spring", stiffness: 340, damping: 30, delay: 0.05 }}
            className="relative w-full max-w-md rounded-2xl border border-red-500/20
              backdrop-blur-2xl overflow-hidden"
            style={{
              background: "hsl(230 25% 7% / 0.97)",
              boxShadow: "0 0 80px -20px hsl(0 80% 55% / 0.4), 0 32px 64px rgba(0,0,0,0.7)",
            }}
          >
            {/* Red top accent line */}
            <div className="h-px w-full bg-gradient-to-r from-transparent via-red-500/60 to-transparent" />

            <div className="p-8 flex flex-col items-center gap-6">

              {/* Dismiss button */}
              <button
                onClick={onDismiss}
                className="absolute top-4 right-4 p-1.5 rounded-lg
                  border border-border/30 text-muted-foreground
                  hover:text-foreground hover:border-border/60 transition-all"
              >
                <X className="w-3.5 h-3.5" />
              </button>

              {/* Animated icon */}
              <div className="relative flex items-center justify-center w-16 h-16">
                {[1, 1.55, 2.1].map((scale, i) => (
                  <motion.div
                    key={i}
                    className="absolute rounded-full border border-red-500/25"
                    style={{ width: "100%", height: "100%" }}
                    animate={{ scale: [1, scale, 1], opacity: [0.6, 0, 0.6] }}
                    transition={{ duration: 2.2, repeat: Infinity, delay: i * 0.55 }}
                  />
                ))}
                <div className="w-11 h-11 rounded-full flex items-center justify-center
                  border border-red-500/50"
                  style={{ background: "hsl(0 70% 20% / 0.5)" }}>
                  <motion.div
                    animate={{ opacity: [0.6, 1, 0.6] }}
                    transition={{ duration: 1.8, repeat: Infinity }}
                  >
                    <WifiOff className="w-5 h-5 text-red-400" />
                  </motion.div>
                </div>
              </div>

              {/* Title */}
              <div className="text-center">
                <h2 className="text-xl font-bold tracking-[0.2em] text-foreground">
                  SIGNAL LOST
                </h2>
                <p className="font-mono text-[10px] tracking-[0.25em] text-red-400/80 mt-1">
                  MUSE 2 · BLUETOOTH DISCONNECTED
                </p>
              </div>

              {/* Dead signal bars */}
              <DeadBars />

              {/* Description */}
              <p className="text-sm text-muted-foreground text-center leading-relaxed max-w-xs">
                The EEG headset stopped sending data.
                The visual output is paused — no data is being sent to TouchDesigner.
              </p>

              {/* Checklist */}
              <div className="w-full flex flex-col gap-3">
                {[
                  { n: 1, text: <>Make sure the <strong className="text-foreground/80">Muse 2</strong> headset is on and fitted correctly.</> },
                  { n: 2, text: <>Check that the <strong className="text-foreground/80">Sentio backend</strong> is still running — <code className="font-mono text-[10px] text-red-400/70 bg-red-950/40 px-1.5 py-0.5 rounded">uvicorn main:app</code></> },
                  { n: 3, text: <>If Bluetooth dropped, re-pair in system settings and <strong className="text-foreground/80">restart the session</strong>.</> },
                ].map(({ n, text }) => (
                  <div key={n} className="flex items-start gap-3">
                    <div className="shrink-0 w-5 h-5 rounded-full border border-border/40
                      flex items-center justify-center mt-0.5">
                      <span className="font-mono text-[9px] text-muted-foreground">{n}</span>
                    </div>
                    <p className="text-[12px] text-muted-foreground leading-relaxed">{text}</p>
                  </div>
                ))}
              </div>

              {/* Footer — countdown + dismiss */}
              <div className="w-full flex items-center justify-between pt-2
                border-t border-border/20">
                <div className="flex items-center gap-2 font-mono text-[9px]
                  tracking-widest text-muted-foreground/50">
                  <RefreshCw className="w-3 h-3" />
                  AUTO-RETRY IN{" "}
                  <span className="text-red-400/70">{countdown}s</span>
                </div>
                <button
                  onClick={onDismiss}
                  className="px-4 py-1.5 rounded-lg border border-border/30
                    font-mono text-[9px] tracking-widest text-muted-foreground
                    hover:text-foreground hover:border-border/60 transition-all"
                >
                  DISMISS
                </button>
              </div>
            </div>

            {/* Red bottom accent line */}
            <div className="h-px w-full bg-gradient-to-r from-transparent via-red-500/40 to-transparent" />
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
