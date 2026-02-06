import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import { commands } from "./bindings";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { RouterProvider, createRouter } from '@tanstack/react-router';
import { routeTree } from './routeTree.gen'

const systemTheme = await commands.getSystemTheme();
for (const [key, value] of Object.entries(systemTheme)) {
  if (value !== null) {
    const keyName = key.replace("_", "-");
    document.documentElement.style.setProperty(`--${keyName}`, `rgba(${value.red}, ${value.green}, ${value.blue}, ${value.alpha})`);
  }
}

export const titlebarLayout = await commands.getTitlebarLayout();

await getCurrentWindow().show();

const router = createRouter({ routeTree });

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router
  }
}

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <RouterProvider router={router} />
  </React.StrictMode>,
);
