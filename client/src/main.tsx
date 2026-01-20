import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import { commands } from "./bindings";
import { getCurrentWindow } from "@tauri-apps/api/window";

const systemTheme = await commands.getSystemTheme();
for (const [key, value] of Object.entries(systemTheme)) {
  if (value !== null) {
    const keyName = key.replace("_", "-");
    document.documentElement.style.setProperty(`--${keyName}`, `rgba(${value.red}, ${value.green}, ${value.blue}, ${value.alpha})`);
  }
}

await getCurrentWindow().show();

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
