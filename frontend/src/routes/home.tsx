import { Button } from "~/components/button";
import "~/styles/global.css";
import { createFileRoute, Link } from '@tanstack/react-router'

export const Route = createFileRoute('/home')({
  component: Index,
})

function Index() {
  return (
      <div className="flex-1 min-h-0 overflow-auto flex flex-col items-center justify-center gap-6">
        <h1 className="text-4xl font-semibold text-fg">Oscope Client</h1>
        <Button intent="outline"><Link to="/test">Test Panel</Link></Button>
      </div>
  );
}
