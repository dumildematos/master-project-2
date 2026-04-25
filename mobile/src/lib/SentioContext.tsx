/**
 * SentioContext
 * -------------
 * Single WebSocket connection shared across all screens via React context.
 * Wrap the app root once — every screen/component calls useSentio() to read.
 */
import React, { createContext, useContext } from "react";
import { useSentioWebSocket, SentioState, BandHistory, EmotionHistoryEntry } from "../hooks/useSentioWebSocket";

interface SentioCtx {
  data:           SentioState;
  connected:      boolean;
  hasSignal:      boolean;
  history:        BandHistory[];
  emotionHistory: EmotionHistoryEntry[];
  reconnect:      () => Promise<void>;
}

const Ctx = createContext<SentioCtx | null>(null);

export function SentioProvider({ children }: { children: React.ReactNode }) {
  const ws = useSentioWebSocket();
  return <Ctx.Provider value={ws}>{children}</Ctx.Provider>;
}

export function useSentio(): SentioCtx {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useSentio must be used inside <SentioProvider>");
  return ctx;
}
