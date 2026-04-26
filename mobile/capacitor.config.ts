import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.dumildematos.sentio",
  appName: "Sentio",
  webDir: "dist",
  plugins: {
    BluetoothLe: {
      displayStrings: {
        scanning: "Scanning for Muse 2…",
        cancel: "Cancel",
        availableDevices: "Available Devices",
        noDeviceFound: "No Muse headset found",
      },
    },
  },
  android: {
    buildOptions: {
      signingType: "apksigner",
    },
  },
};

export default config;
