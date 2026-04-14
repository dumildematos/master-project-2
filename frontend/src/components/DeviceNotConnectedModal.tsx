import React from "react";
import { motion, AnimatePresence } from "framer-motion";
import { RefreshCw, ArrowRight, X, Bluetooth, BluetoothOff, AlertTriangle } from "lucide-react";

interface Props {
  open:            boolean;
  onClose:         () => void;
  onRetry:         () => void;
  onContinueAnyway:() => void;
  retrying:        boolean;
}

const TIPS = [
  "Make sure BlueMuse is open and running",
  "Confirm the Muse 2 headband is powered on",
  "Check Bluetooth is enabled on this computer",
  "Verify the MAC address in Device Settings (⚙)",
];

export default function DeviceNotConnectedModal({
  open, onClose, onRetry, onContinueAnyway, retrying,
}: Props) {
  return (
    <AnimatePresence>
      {open && (
        <>
          {/* Backdrop */}
          <motion.div
            key="backdrop"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.25 }}
            className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm"
            onClick={onClose}
          />

          {/* Modal */}
          <motion.div
            key="modal"
            initial={{ opacity: 0, scale: 0.92, y: 16 }}
            animate={{ opacity: 1, scale: 1,    y: 0  }}
            exit={{   opacity: 0, scale: 0.92, y: 16 }}
            transition={{ type: "spring", stiffness: 280, damping: 24 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-6 pointer-events-none"
          >
            <div
              className="glass-card gradient-border w-full max-w-md p-8 flex flex-col gap-6 pointer-events-auto"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Close */}
              <button
                onClick={onClose}
                className="absolute top-4 right-4 p-1.5 rounded-lg text-muted-foreground hover:text-foreground transition-colors"
              >
                <X className="w-4 h-4" />
              </button>

              {/* Icon area */}
              <div className="flex flex-col items-center gap-4">
                <div className="relative flex items-center justify-center">
                  {/* Pulsing red glow */}
                  <motion.div
                    className="absolute rounded-full"
                    style={{ width: 88, height: 88, background: "radial-gradient(circle, hsl(0 84% 60% / 0.2), transparent 70%)" }}
                    animate={{ scale: [1, 1.2, 1], opacity: [0.5, 0.9, 0.5] }}
                    transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
                  />

                  {/* Device SVG */}
                  <div className="relative w-16 h-16 rounded-full flex items-center justify-center"
                    style={{ background: "hsl(230 20% 14%)", border: "1px solid hsl(0 84% 60% / 0.3)" }}>
                    <BluetoothOff className="w-7 h-7" style={{ color: "hsl(0 84% 60%)" }} />

                    {/* Headband arc */}
                    <svg
                      viewBox="0 0 80 36"
                      className="absolute -top-3 left-1/2 -translate-x-1/2 w-20 opacity-50"
                    >
                      <path
                        d="M 8 28 Q 40 2 72 28"
                        fill="none"
                        stroke="hsl(0 84% 60%)"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeDasharray="4 3"
                      />
                      <circle cx="8"  cy="28" r="3" fill="hsl(0 84% 60%)" opacity="0.7" />
                      <circle cx="72" cy="28" r="3" fill="hsl(0 84% 60%)" opacity="0.7" />
                      {/* X mark in centre */}
                      <line x1="36" y1="10" x2="44" y2="18" stroke="hsl(0 84% 60%)" strokeWidth="2" strokeLinecap="round" />
                      <line x1="44" y1="10" x2="36" y2="18" stroke="hsl(0 84% 60%)" strokeWidth="2" strokeLinecap="round" />
                    </svg>
                  </div>
                </div>

                <div className="text-center space-y-1">
                  <div className="flex items-center justify-center gap-2">
                    <AlertTriangle className="w-4 h-4" style={{ color: "hsl(38 92% 60%)" }} />
                    <h3 className="text-lg font-semibold text-foreground">Muse 2 Not Detected</h3>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    No EEG device was found. Check the steps below and try again.
                  </p>
                </div>
              </div>

              {/* Checklist */}
              <ul className="space-y-2.5">
                {TIPS.map((tip, i) => (
                  <motion.li
                    key={i}
                    initial={{ opacity: 0, x: -8 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.1 + i * 0.07 }}
                    className="flex items-start gap-3"
                  >
                    <span
                      className="mt-0.5 w-5 h-5 rounded-full flex items-center justify-center shrink-0 mono text-[10px] font-bold"
                      style={{ background: "hsl(230 20% 18%)", color: "hsl(187 80% 55%)" }}
                    >
                      {i + 1}
                    </span>
                    <span className="text-sm text-muted-foreground leading-snug">{tip}</span>
                  </motion.li>
                ))}
              </ul>

              {/* Actions */}
              <div className="flex flex-col gap-2.5 pt-1">
                <button
                  onClick={onRetry}
                  disabled={retrying}
                  className="w-full py-3 rounded-xl font-semibold text-sm flex items-center justify-center gap-2 transition-all
                    bg-primary text-primary-foreground
                    hover:shadow-[0_0_24px_hsl(187_80%_55%/0.35)]
                    disabled:opacity-60 disabled:cursor-not-allowed"
                >
                  <motion.span
                    animate={retrying ? { rotate: 360 } : { rotate: 0 }}
                    transition={{ duration: 0.8, repeat: retrying ? Infinity : 0, ease: "linear" }}
                    className="inline-flex"
                  >
                    <RefreshCw className="w-4 h-4" />
                  </motion.span>
                  {retrying ? "Checking…" : "Try Again"}
                </button>

                <button
                  onClick={onContinueAnyway}
                  className="w-full py-3 rounded-xl font-semibold text-sm flex items-center justify-center gap-2 transition-all
                    border border-border/40 text-muted-foreground
                    hover:border-border/70 hover:text-foreground"
                >
                  Continue Without Device
                  <ArrowRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
