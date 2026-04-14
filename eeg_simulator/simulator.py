"""
EEG Simulator
Generates synthetic EEG data and publishes it as an LSL stream,
mimicking the Muse headband + BlueMuse pipeline.

Use this for development and testing when no physical Muse headband is available.

Run:
  python simulator.py [--scenario calm|focused|stressed|meditative|drowsy|cycle]

Scenarios:
  calm        — sustained high alpha, low beta
  focused     — high beta, moderate alpha
  stressed    — very high beta, low alpha
  meditative  — high theta, moderate alpha
  drowsy      — high theta, low beta
  cycle       — rotates through all states every 10 seconds (default)
"""

import argparse
import time
import numpy as np
from pylsl import StreamInfo, StreamOutlet

SAMPLE_RATE = 256   # Hz — matches real Muse hardware
N_CHANNELS  = 4     # TP9, AF7, AF8, TP10
CHUNK_SIZE  = 32    # samples per push

# Band centre frequencies (Hz)
BANDS = {"delta": 2, "theta": 5.5, "alpha": 10, "beta": 20, "gamma": 40}

# Scenario definitions: weights per band (relative amplitude)
SCENARIOS: dict[str, dict[str, float]] = {
    "calm":       {"delta": 0.1, "theta": 0.2, "alpha": 0.8, "beta": 0.1, "gamma": 0.05},
    "focused":    {"delta": 0.1, "theta": 0.2, "alpha": 0.3, "beta": 0.8, "gamma": 0.10},
    "stressed":   {"delta": 0.1, "theta": 0.1, "alpha": 0.1, "beta": 0.9, "gamma": 0.15},
    "meditative": {"delta": 0.1, "theta": 0.8, "alpha": 0.5, "beta": 0.1, "gamma": 0.03},
    "drowsy":     {"delta": 0.3, "theta": 0.7, "alpha": 0.4, "beta": 0.1, "gamma": 0.02},
}

CYCLE_ORDER    = ["calm", "focused", "stressed", "meditative", "drowsy"]
CYCLE_DURATION = 10.0  # seconds per scenario


def generate_chunk(weights: dict[str, float], n_samples: int, fs: int) -> list[list[float]]:
    """Synthesize EEG-like samples by summing sinusoids for each frequency band."""
    t = np.linspace(0, n_samples / fs, n_samples, endpoint=False)
    signal = np.zeros(n_samples)

    for band, freq in BANDS.items():
        amp = weights.get(band, 0.1)
        phase = np.random.uniform(0, 2 * np.pi)
        signal += amp * np.sin(2 * np.pi * freq * t + phase)

    # Add mild noise
    signal += np.random.normal(0, 0.05, n_samples)

    # Replicate across 4 channels with small per-channel variance
    samples = []
    for i in range(n_samples):
        row = [signal[i] + np.random.normal(0, 0.02) for _ in range(N_CHANNELS)]
        samples.append(row)
    return samples


def run(scenario: str):
    info = StreamInfo(
        name="MuseSimulator",
        type="EEG",
        channel_count=N_CHANNELS,
        nominal_srate=SAMPLE_RATE,
        channel_format="float32",
        source_id="sentio_simulator",
    )
    outlet = StreamOutlet(info)
    print(f"[Simulator] LSL stream 'MuseSimulator' started @ {SAMPLE_RATE} Hz, {N_CHANNELS} channels")

    cycle = scenario == "cycle"
    cycle_index = 0
    cycle_start = time.time()
    current_scenario = CYCLE_ORDER[0] if cycle else scenario
    chunk_interval = CHUNK_SIZE / SAMPLE_RATE

    print(f"[Simulator] Initial scenario: {current_scenario}")

    while True:
        if cycle:
            elapsed = time.time() - cycle_start
            new_index = int(elapsed / CYCLE_DURATION) % len(CYCLE_ORDER)
            if new_index != cycle_index:
                cycle_index = new_index
                current_scenario = CYCLE_ORDER[cycle_index]
                print(f"[Simulator] → Switched to: {current_scenario}")

        weights = SCENARIOS[current_scenario]
        chunk = generate_chunk(weights, CHUNK_SIZE, SAMPLE_RATE)
        outlet.push_chunk(chunk)
        time.sleep(chunk_interval)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Sentio EEG Simulator")
    parser.add_argument(
        "--scenario",
        choices=[*SCENARIOS.keys(), "cycle"],
        default="cycle",
        help="EEG scenario to simulate (default: cycle through all)",
    )
    args = parser.parse_args()
    run(args.scenario)
