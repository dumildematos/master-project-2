import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import { BrainProvider } from "./context/BrainContext.tsx";
import "./index.css";

createRoot(document.getElementById("root")!).render(
	<BrainProvider>
		<App />
	</BrainProvider>,
);
