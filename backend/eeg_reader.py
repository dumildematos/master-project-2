"""
EEG Acquisition Layer
Reads EEG data from the LSL stream produced by BlueMuse (Muse headband).
"""

import time
from pylsl import StreamInlet, resolve_stream


def connect_to_stream(stream_type: str = "EEG", timeout: float = 10.0) -> StreamInlet:
    """Resolve and connect to the first available LSL EEG stream."""
    print(f"[EEGReader] Searching for LSL stream of type '{stream_type}'...")
    streams = resolve_stream("type", stream_type, timeout=timeout)
    if not streams:
        raise RuntimeError(
            f"No LSL stream of type '{stream_type}' found. "
            "Ensure BlueMuse is running and the Muse headband is connected."
        )
    inlet = StreamInlet(streams[0])
    info = inlet.info()
    print(f"[EEGReader] Connected: {info.name()} @ {info.nominal_srate()} Hz, {info.channel_count()} channels")
    return inlet


def read_chunk(inlet: StreamInlet, max_samples: int = 256):
    """
    Pull a chunk of samples from the inlet.
    Returns (samples, timestamps) where samples is a list of channel arrays.
    """
    samples, timestamps = inlet.pull_chunk(max_samples=max_samples)
    return samples, timestamps
