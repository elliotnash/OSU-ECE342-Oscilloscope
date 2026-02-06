import { createRootRoute, Outlet } from '@tanstack/react-router';
import { TanStackRouterDevtools } from '@tanstack/react-router-devtools';
import { useEffect } from 'react';
import { commands, events, SerialStatus } from '~/bindings';
import { Titlebar } from '~/components/titlebar';
import { useNavigate } from '@tanstack/react-router';
import { info } from '@tauri-apps/plugin-log';

function RootLayout() {
  const navigate = useNavigate();
  
  let unlisten: ReturnType<typeof events.serialStatus.listen>;
  // biome-ignore lint/correctness/useExhaustiveDependencies: listen
  useEffect(() => {
    function updateRoute(status: SerialStatus) {
      if (status === "Connected") {
        navigate({ to: "/home" });
      } else {
          navigate({ to: "/" });
      }
    }

    commands.getSerialStatus().then(updateRoute);
    unlisten = events.serialStatus.listen((status) => {
      updateRoute(status.payload);
    });

    return () => {
      unlisten.then((unlisten) => unlisten());
    }
  }, [navigate]);

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
        <Outlet />
        <TanStackRouterDevtools />
    </main>
  )
}    

export const Route = createRootRoute({ component: RootLayout })