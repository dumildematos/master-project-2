import React, { useState } from "react";
import { AnimatePresence } from "framer-motion";
import ConfigurationScreen from "./components/ConfigurationScreen";
import CalibrationScreen   from "./components/CalibrationScreen";
import MonitoringScreen    from "./components/MonitoringScreen";
import type { AppScreen, SessionConfig } from "./types";

export default function App() {
  const [screen, setScreen] = useState<AppScreen>("config");
  const [config, setConfig] = useState<SessionConfig>({
    patternType: "organic",
    sensitivity: 50,
  });

  return (
    <div className="min-h-screen neural-bg overflow-hidden">
      <AnimatePresence mode="wait">
        {screen === "config" && (
          <ConfigurationScreen
            key="config"
            config={config}
            setConfig={setConfig}
            onStart={() => setScreen("calibration")}
          />
        )}

        {screen === "calibration" && (
          <CalibrationScreen
            key="calibration"
            onComplete={() => setScreen("monitoring")}
          />
        )}

        {screen === "monitoring" && (
          <MonitoringScreen
            key="monitoring"
            config={config}
            onBack={() => setScreen("config")}
          />
        )}
      </AnimatePresence>
    </div>
  );
}
