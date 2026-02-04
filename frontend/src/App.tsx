import { useEffect } from "react";
import { Button } from "~/components/button";
import "~/styles/global.css";
import { Titlebar } from "~/components/titlebar";

function App() {

  // Set the system theme
  useEffect(() => {
    const systemTheme = window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light"
    window.document.documentElement.classList.add(systemTheme)
  })

  return (
    <main className="h-screen flex flex-col overflow-hidden">
      <Titlebar />
      <div className="flex-1 min-h-0 overflow-auto flex flex-col items-center justify-center gap-6">
        <h1 className="text-4xl font-semibold text-fg">Oscope Client</h1>
        <Button intent="outline">Test</Button>
      </div>
    </main>
  );
}

export default App;
