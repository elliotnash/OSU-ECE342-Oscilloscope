import { getCurrentWindow } from "@tauri-apps/api/window";
import { useEffect, useState } from "react";

const appWindow = getCurrentWindow();

export function useIsMaximized() {
    const [isMaximized, setIsMaximized] = useState<boolean>(false);
  
    useEffect(() => {
        function handleResize() {
            appWindow.isMaximized().then((newState) => setIsMaximized(newState));
        }
        handleResize();

        const unlisten = appWindow.listen('tauri://resize', async () => {
            handleResize();
        });
        return () => {
            unlisten.then((u) => u());
        };
    }, []);
  
    return { isMaximized };
}