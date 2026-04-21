import { motion } from "framer-motion";
import { useEffect, useMemo, useState, type ReactNode } from "react";
import { Activity, Zap, Waves, Signal, Eye } from "lucide-react";
import { useBrainContext } from "../../context/BrainContext";
import { formatEmotionLabel, getEmotionMeta } from "../../lib/emotionMeta";

interface Props {
  onPatternReady: () => void;
}

const MAX_POINTS = 120;

const trimSeries = (series: number[]) => series.slice(-MAX_POINTS);

const getWaveGraphScale = (series: number[]) => {
  const maxAbsValue = Math.max(...series.map((value) => Math.abs(value)), 0);

  if (maxAbsValue === 0 || maxAbsValue > 5) {
    return 1;
  }

  return 40;
};

const toPolylinePoints = (series: number[], scale = 1) =>
  series.map((value, index) => `${index},${50 - value * scale}`).join(" ");

const formatSeries = (series: number[]) => series.map((value) => value.toFixed(2)).join(", ");

const MonitoringScreen = ({ onPatternReady }: Props) => {
  const { calibration, brainData } = useBrainContext();
  const [elapsed, setElapsed] = useState(0);

  useEffect(() => {
    if (!calibration) {
      setElapsed(0);
    }
  }, [calibration]);

  useEffect(() => {
    if (!brainData) {
      return;
    }

    setElapsed((current) => current + 1);
  }, [brainData]);

  const emotion = useMemo(() => getEmotionMeta(brainData?.emotion), [brainData?.emotion]);

  const eegData = brainData?.eegData?.length ? trimSeries(brainData.eegData) : [];
  const alphaData = brainData?.alphaWave?.length ? trimSeries(brainData.alphaWave) : [];
  const betaData = brainData?.betaWave?.length ? trimSeries(brainData.betaWave) : [];
  const gammaData = brainData?.gammaWave?.length ? trimSeries(brainData.gammaWave) : [];
  const thetaData = brainData?.thetaWave?.length ? trimSeries(brainData.thetaWave) : [];
  const alpha = brainData?.alpha ?? 0;
  const beta = brainData?.beta ?? 0;
  const confidence = brainData?.confidence ?? 0;
  const gamma = brainData?.gamma ?? 0;
  const theta = brainData?.theta ?? 0;
  const heartBpm = brainData?.heartBpm ?? null;
  const respirationRpm = brainData?.respirationRpm ?? null;
  const signal = brainData?.signal_quality ?? 0;
  const isConnected = Boolean(brainData);
  const eegPoints = toPolylinePoints(eegData);
  const alphaPoints = toPolylinePoints(alphaData, getWaveGraphScale(alphaData));
  const betaPoints = toPolylinePoints(betaData, getWaveGraphScale(betaData));
  const gammaPoints = toPolylinePoints(gammaData, getWaveGraphScale(gammaData));
  const thetaPoints = toPolylinePoints(thetaData, getWaveGraphScale(thetaData));

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.5 }}
      className="min-h-screen p-4 md:p-8 flex flex-col"
    >
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <Activity className="w-5 h-5 text-primary" />
          <h1 className="text-xl font-bold glow-text-cyan">Live Monitoring</h1>
        </div>
        <div className="flex items-center gap-4">
          <span className="text-xs font-mono text-muted-foreground">
            {Math.floor(elapsed / 600).toString().padStart(2, "0")}:
            {Math.floor((elapsed / 10) % 60).toString().padStart(2, "0")}
          </span>
          <div className="flex items-center gap-1.5">
            <div className={`w-2 h-2 rounded-full ${isConnected ? "bg-green-400 animate-pulse" : "bg-amber-400"}`} />
            <span className="text-xs font-mono text-muted-foreground">
              {isConnected ? "Connected" : "Waiting for stream"}
            </span>
          </div>
        </div>
      </div>

      {/* Main Grid */}
      <div className="flex-1 grid grid-cols-1 lg:grid-cols-4 gap-4">
        {/* EEG Graph - Main */}
        <div className="lg:col-span-3 glass-card p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-mono text-muted-foreground">EEG Brainwave Signal</h2>
            <Waves className="w-4 h-4 text-primary/50" />
          </div>
          <div className="h-48 md:h-64 w-full relative overflow-hidden rounded-xl bg-muted/20">
            <svg
              viewBox={`0 0 120 100`}
              className="w-full h-full"
              preserveAspectRatio="none"
            >
              {/* Grid */}
              {Array.from({ length: 12 }, (_, i) => (
                <line key={`gv${i}`} x1={i * 10} y1="0" x2={i * 10} y2="100" stroke="hsl(230 15% 18%)" strokeWidth="0.3" />
              ))}
              {Array.from({ length: 10 }, (_, i) => (
                <line key={`gh${i}`} x1="0" y1={i * 10} x2="120" y2={i * 10} stroke="hsl(230 15% 18%)" strokeWidth="0.3" />
              ))}
              {/* EEG Signal */}
              {eegData.length > 1 && (
                <polyline
                  points={eegPoints}
                  fill="none"
                  stroke={emotion.color}
                  strokeWidth="1.5"
                  strokeLinejoin="round"
                  vectorEffect="non-scaling-stroke"
                />
              )}
              {/* Alpha Wave */}
              {alphaData.length > 1 && (
                <polyline
                  points={alphaPoints}
                  fill="none"
                  stroke="hsl(187 80% 55%)"
                  strokeWidth="1.5"
                  strokeLinejoin="round"
                  vectorEffect="non-scaling-stroke"
                />
              )}
              {/* Beta Wave */}
              {betaData.length > 1 && (
                <polyline
                  points={betaPoints}
                  fill="none"
                  stroke="hsl(270 60% 55%)"
                  strokeWidth="1.5"
                  strokeLinejoin="round"
                  vectorEffect="non-scaling-stroke"
                />
              )}
              {/* Gamma Wave */}
              {gammaData.length > 1 && (
                <polyline
                  points={gammaPoints}
                  fill="none"
                  stroke="hsl(310 60% 55%)"
                  strokeWidth="1.5"
                  strokeLinejoin="round"
                  vectorEffect="non-scaling-stroke"
                />
              )}
              {/* Theta Wave */}
              {thetaData.length > 1 && (
                <polyline
                  points={thetaPoints}
                  fill="none"
                  stroke="hsl(220 70% 55%)"
                  strokeWidth="1.5"
                  strokeLinejoin="round"
                  vectorEffect="non-scaling-stroke"
                />
              )}
            </svg>
            {/* Legend */}
            <div className="flex gap-4 mt-2 text-xs font-mono text-muted-foreground">
              <span><span style={{color: emotion.color}}>●</span> EEG</span>
              <span><span style={{color: 'hsl(187 80% 55%)'}}>●</span> Alpha</span>
              <span><span style={{color: 'hsl(270 60% 55%)'}}>●</span> Beta</span>
              <span><span style={{color: 'hsl(310 60% 55%)'}}>●</span> Gamma</span>
              <span><span style={{color: 'hsl(220 70% 55%)'}}>●</span> Theta</span>
            </div>
            {/* Show numeric values below graph */}
            {eegData.length > 0 && (
              <div className="mt-2 text-xs font-mono text-muted-foreground overflow-x-auto whitespace-nowrap">
                <span>EEG: {formatSeries(eegData)}</span>
              </div>
            )}
            {alphaData.length > 0 && (
              <div className="mt-1 text-xs font-mono text-muted-foreground overflow-x-auto whitespace-nowrap">
                <span>Alpha: {formatSeries(alphaData)}</span>
              </div>
            )}
            {betaData.length > 0 && (
              <div className="mt-1 text-xs font-mono text-muted-foreground overflow-x-auto whitespace-nowrap">
                <span>Beta: {formatSeries(betaData)}</span>
              </div>
            )}
            {gammaData.length > 0 && (
              <div className="mt-1 text-xs font-mono text-muted-foreground overflow-x-auto whitespace-nowrap">
                <span>Gamma: {formatSeries(gammaData)}</span>
              </div>
            )}
            {thetaData.length > 0 && (
              <div className="mt-1 text-xs font-mono text-muted-foreground overflow-x-auto whitespace-nowrap">
                <span>Theta: {formatSeries(thetaData)}</span>
              </div>
            )}
          </div>
        </div>

        {/* Side panels */}
        <div className="space-y-4">
          {/* Emotion */}
          <motion.div
            key={brainData?.emotion ?? emotion.label}
            initial={{ scale: 0.95, opacity: 0.8 }}
            animate={{ scale: 1, opacity: 1 }}
            className="glass-card-purple p-5"
          >
            <div className="flex items-center gap-2 mb-3">
              <Eye className="w-4 h-4 text-muted-foreground" />
              <h3 className="text-xs font-mono text-muted-foreground">Detected Emotion</h3>
            </div>
            <p className="text-2xl font-bold" style={{ color: emotion.color }}>
              {formatEmotionLabel(brainData?.emotion)}
            </p>
            <div className="mt-3 h-1.5 rounded-full overflow-hidden bg-muted/30">
              <motion.div
                className="h-full rounded-full"
                style={{ background: emotion.color }}
                animate={{ width: `${Math.max(confidence, 12)}%` }}
                transition={{ duration: 0.25 }}
              />
            </div>
          </motion.div>

          {/* Wave data */}
          <DataCard icon={<Zap className="w-4 h-4" />} label="Alpha" value={alpha.toFixed(2)} unit="μV" color="hsl(187 80% 55%)" />
          <DataCard icon={<Activity className="w-4 h-4" />} label="Beta" value={beta.toFixed(2)} unit="μV" color="hsl(270 60% 55%)" />
          <DataCard icon={<Waves className="w-4 h-4" />} label="Gamma" value={gamma.toFixed(2)} unit="μV" color="hsl(310 60% 55%)" />
          <DataCard icon={<Activity className="w-4 h-4" />} label="Theta" value={theta.toFixed(2)} unit="μV" color="hsl(220 70% 55%)" />
          <DataCard icon={<Activity className="w-4 h-4" />} label="Heart" value={heartBpm === null ? "--" : heartBpm.toFixed(1)} unit="bpm" color="hsl(12 85% 60%)" />
          <DataCard icon={<Waves className="w-4 h-4" />} label="Respiration" value={respirationRpm === null ? "--" : respirationRpm.toFixed(1)} unit="rpm" color="hsl(160 65% 55%)" />
          <DataCard icon={<Signal className="w-4 h-4" />} label="Signal" value={signal.toFixed(0)} unit="%" color="hsl(140 60% 50%)" />
        </div>
      </div>

      {/* Generate button */}
      <div className="mt-6 flex justify-center">
        <button
          onClick={onPatternReady}
          className="px-8 py-3 rounded-xl font-semibold text-sm bg-primary text-primary-foreground hover:shadow-[0_0_30px_hsl(187_80%_55%/0.3)] transition-all"
        >
          Generate Fabric Pattern
        </button>
      </div>
    </motion.div>
  );
};

const DataCard = ({ icon, label, value, unit, color }: { icon: ReactNode; label: string; value: string; unit: string; color: string }) => (
  <div className="glass-card p-4 flex items-center justify-between">
    <div className="flex items-center gap-2 text-muted-foreground">
      {icon}
      <span className="text-xs font-mono">{label}</span>
    </div>
    <div className="text-right">
      <span className="text-lg font-bold font-mono" style={{ color }}>{value}</span>
      <span className="text-xs text-muted-foreground ml-1">{unit}</span>
    </div>
  </div>
);

export default MonitoringScreen;
