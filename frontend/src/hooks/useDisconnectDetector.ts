import { useEffect, useRef, useState, useCallback } from "react";

// ---------------------------------------------------------------------------
// Detects when a live EEG session loses connection to the Muse 2 device.
//
// Rules:
//  - Only activates AFTER the session has been live (connected + hasSignal).
//  - Triggers when signal_quality < DISCONNECT_THRESHOLD for > GRACE_SECONDS.
//  - Also triggers immediately if the WebSocket closes while live.
//  - Auto-recovers when signal_quality rises back above RECOVER_THRESHOLD.
// ---------------------------------------------------------------------------

const DISCONNECT_THRESHOLD = 15;   // signal_quality below this = bad (0-100 scale)
const RECOVER_THRESHOLD    = 38;   // signal_quality above this = restored
const GRACE_SECONDS        = 1.8;  // seconds below threshold before popup shows

interface Args {
  connected:      boolean;
  hasSignal:      boolean;
  signal_quality: number;
  isManualMode:   boolean;  // suppress detector in manual mode
}

export function useDisconnectDetector({ connected, hasSignal, signal_quality, isManualMode }: Args) {
  const [isDisconnected,    setIsDisconnected]    = useState(false);
  const [showReconnectToast, setShowReconnectToast] = useState(false);

  const wasLiveRef       = useRef(false);  // true once we've had a live reading
  const lowTimerRef      = useRef<ReturnType<typeof setTimeout> | null>(null);
  const dismissedRef     = useRef(false);
  const toastTimerRef    = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Track whether we've ever been live
  useEffect(() => {
    if (connected && hasSignal && !isManualMode) {
      wasLiveRef.current = true;
    }
  }, [connected, hasSignal, isManualMode]);

  // Main detection logic
  useEffect(() => {
    if (isManualMode || !wasLiveRef.current) return;

    const bad = !connected || signal_quality < DISCONNECT_THRESHOLD;

    if (bad) {
      // Start grace-period timer if not already running
      if (!lowTimerRef.current && !isDisconnected && !dismissedRef.current) {
        lowTimerRef.current = setTimeout(() => {
          setIsDisconnected(true);
          dismissedRef.current = false;
        }, GRACE_SECONDS * 1000);
      }
    } else {
      // Signal looks good — cancel any pending timer
      if (lowTimerRef.current) {
        clearTimeout(lowTimerRef.current);
        lowTimerRef.current = null;
      }

      // If we were disconnected, trigger recovery
      if (isDisconnected || dismissedRef.current) {
        if (signal_quality >= RECOVER_THRESHOLD && connected) {
          setIsDisconnected(false);
          dismissedRef.current = false;

          // Show reconnect toast briefly
          setShowReconnectToast(true);
          if (toastTimerRef.current) clearTimeout(toastTimerRef.current);
          toastTimerRef.current = setTimeout(() => setShowReconnectToast(false), 3200);
        }
      }
    }
  }, [connected, hasSignal, signal_quality, isManualMode, isDisconnected]);

  // Cleanup timers on unmount
  useEffect(() => {
    return () => {
      if (lowTimerRef.current)   clearTimeout(lowTimerRef.current);
      if (toastTimerRef.current) clearTimeout(toastTimerRef.current);
    };
  }, []);

  const dismiss = useCallback(() => {
    dismissedRef.current = true;
    setIsDisconnected(false);
  }, []);

  return { isDisconnected, showReconnectToast, dismiss };
}
