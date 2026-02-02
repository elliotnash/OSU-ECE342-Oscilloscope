import { useEffect } from "react";
import { Button } from "~/components/button";
import "~/styles/global.css";

function App() {

  useEffect(() => {
    const systemTheme = window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light"
    window.document.documentElement.classList.add(systemTheme)
  })

  return (
    <main className="min-h-screen flex flex-col items-center justify-center gap-6">
      <h1 className="text-4xl font-semibold text-white">Oscope Client</h1>
      <Button intent="plain">Test</Button>
    </main>
  );
}

export default App;
