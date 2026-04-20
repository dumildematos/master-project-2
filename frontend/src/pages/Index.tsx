import { useState } from "react";
import { AnimatePresence } from "framer-motion";
import ConfigurationScreen from "@/components/sentio/ConfigurationScreen";
import CalibrationScreen from "@/components/sentio/CalibrationScreen";
import MonitoringScreen from "@/components/sentio/MonitoringScreen";
import PatternScreen from "@/components/sentio/PatternScreen";

export type GridSize = "8x8" | "16x16" | "32x32" | "64x64" | "fit";

export type SessionConfig = {
  age: string;
  gender: string;
  patternType: string;
  sensitivity: number;
  gridSize: GridSize;
};

export type AppScreen = "config" | "calibration" | "monitoring" | "pattern";

const Index = () => {
  const [screen, setScreen] = useState<AppScreen>("config");
  const [config, setConfig] = useState<SessionConfig>({
    age: "",
    gender: "",
    patternType: "organic",
    sensitivity: 50,
    gridSize: "16x16",
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
            onPatternReady={() => setScreen("pattern")}
          />
        )}
        {screen === "pattern" && (
          <PatternScreen
            key="pattern"
            onNewSession={() => setScreen("config")}
          />
        )}
      </AnimatePresence>
    </div>
  );
};

export default Index;
