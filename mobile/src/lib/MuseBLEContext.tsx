/**
 * MuseBLEContext  (mobile)
 * ------------------------
 * Shares a single useMuseBLE instance across the whole app so all screens
 * can read BLE state without creating duplicate connections.
 */
import React, { createContext, useContext } from "react";
import { useMuseBLE, BLEState, MuseDevice } from "../hooks/useMuseBLE";
import { BandPowers } from "./museble/bandPowers";

interface MuseBLECtx {
  bleState:        BLEState;
  devices:         MuseDevice[];
  connectedDevice: MuseDevice | null;
  bandPowers:      BandPowers | null;
  signalQuality:   number;
  error:           string | null;
  scan:            () => void;
  stopScan:        () => void;
  connect:         (d: MuseDevice) => Promise<void>;
  disconnect:      () => Promise<void>;
}

const MuseBLEContext = createContext<MuseBLECtx | null>(null);

export function MuseBLEProvider({ children }: { children: React.ReactNode }) {
  const ble = useMuseBLE();
  return <MuseBLEContext.Provider value={ble}>{children}</MuseBLEContext.Provider>;
}

export function useMuseBLEContext(): MuseBLECtx {
  const ctx = useContext(MuseBLEContext);
  if (!ctx) throw new Error("useMuseBLEContext must be inside MuseBLEProvider");
  return ctx;
}
