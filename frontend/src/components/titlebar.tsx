import { info } from "@tauri-apps/plugin-log";
import { useEffect } from "react";
import { titlebarLayout } from "~/main";

export function Titlebar() {
    useEffect(() => {
        info(JSON.stringify(titlebarLayout));
    }, []);

    return (
        <div className="flex items-center justify-between">
            <div className="flex items-center">
                <h1>Titlebar</h1>
            </div>
        </div>
    )
}