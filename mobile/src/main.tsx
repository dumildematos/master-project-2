import React from "react";
import { createRoot } from "react-dom/client";
import { setupIonicReact } from "@ionic/react";

/* Core Ionic CSS */
import "@ionic/react/css/core.css";
import "@ionic/react/css/normalize.css";
import "@ionic/react/css/structure.css";
import "@ionic/react/css/typography.css";
import "@ionic/react/css/padding.css";
import "@ionic/react/css/flex-utils.css";
import "@ionic/react/css/display.css";

/* Sentio dark theme */
import "./theme/variables.css";

import App from "../App";

setupIonicReact({ mode: "md" });

const container = document.getElementById("root")!;
createRoot(container).render(<App />);
