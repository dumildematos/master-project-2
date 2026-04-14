import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import path from "path";
import { componentTagger } from "lovable-tagger";

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => ({
  server: {
    host: "::",
    port: 3000,
    hmr: { overlay: false },
    proxy: {
      "/ws":    { target: "ws://localhost:8000",   ws: true,        changeOrigin: true },
      "/api":   { target: "http://localhost:8000", changeOrigin: true },
      "/state": { target: "http://localhost:8000", changeOrigin: true },
    },
  },
  plugins: [react(), mode === "development" && componentTagger()].filter(Boolean),
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
}));
