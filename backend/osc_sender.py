"""
Real-Time Communication — OSC Sender
Sends design parameters to TouchDesigner via OSC (Open Sound Control).
"""

from pythonosc.udp_client import SimpleUDPClient

from design_mapper import DesignParams

# TouchDesigner listens on localhost by default
TD_HOST = "127.0.0.1"
TD_PORT = 7000  # Match this in your TouchDesigner OSC In CHOP


class OSCSender:
    def __init__(self, host: str = TD_HOST, port: int = TD_PORT):
        self._client = SimpleUDPClient(host, port)
        print(f"[OSCSender] Ready → {host}:{port}")

    def send(self, params: DesignParams) -> None:
        """Send each design parameter as a separate OSC address."""
        d = params.to_dict()
        for key, value in d.items():
            self._client.send_message(f"/sentio/{key}", value)
