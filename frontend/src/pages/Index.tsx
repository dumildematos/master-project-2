import { useState } from "react";
import { AnimatePresence } from "framer-motion";
import ConfigurationScreen from "@/components/sentio/ConfigurationScreen";
import CalibrationScreen from "@/components/sentio/CalibrationScreen";
import MonitoringScreen from "@/components/sentio/MonitoringScreen";
import PatternScreen from "@/components/sentio/PatternScreen";

export type SessionConfig = {
  age: string;
  gender: string;
  patternType: string;
  sensitivity: number;
};

export type AppScreen = "config" | "calibration" | "monitoring" | "pattern";

const Index = () => {
  const [screen, setScreen] = useState<AppScreen>("config");
  const [config, setConfig] = useState<SessionConfig>({
    age: "",
    gender: "",
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
