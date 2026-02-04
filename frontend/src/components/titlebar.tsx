import { getCurrentWindow } from "@tauri-apps/api/window";
import { info } from "@tauri-apps/plugin-log";
import { useEffect } from "react";
import { titlebarLayout } from "~/main";
import { Button } from "~/components/button";
import { Button as RACButton } from "react-aria-components";
import { Bars3Icon } from "@heroicons/react/24/solid";
import { type } from "@tauri-apps/plugin-os";
import WindowMinimizeSymbolic from "~/assets/adwaita/window-minimize-symbolic.svg?react";
import WindowMaximizeSymbolic from "~/assets/adwaita/window-maximize-symbolic.svg?react";
import WindowRestoreSymbolic from "~/assets/adwaita/window-restore-symbolic.svg?react";
import WindowCloseSymbolic from "~/assets/adwaita/window-close-symbolic.svg?react";
import { useIsMaximized } from "~/hooks/use-is-maximized";
import { commands, type TitlebarButton } from "~/bindings";

const osType = type();

const layout = await commands.getTitlebarLayout();

export function Titlebar() {
    useEffect(() => {
        info(JSON.stringify(titlebarLayout));
    }, []);

    return (
        <div className="relative flex items-center w-full h-12">
            {/* Left buttons */}
        
            <div className="flex items-center gap-2 flex-1 min-w-0 justify-start pl-2">
                {layout.left.map(mapTitlebarButton)}
            </div>
            <div className="absolute left-[50vw] -translate-x-1/2 flex items-center gap-2 pointer-events-none">
                <div className="pointer-events-auto flex items-center gap-2 px-2 py-1 text-sm select-none">
                    <h1>Oscope Client</h1>
                </div>
            </div>
            {/* Right buttons */}
            <div className="flex items-center gap-2 flex-1 min-w-0 justify-end pr-2">
                {layout.right.map(mapTitlebarButton)}
            </div>
        </div>
    )
}

function mapTitlebarButton(button: TitlebarButton) {
    switch (button) {
        case "Menu":
            return (
                <Button size="sq-sm" intent="outline">
                    <Bars3Icon/>
                </Button>
            );
        case "Minimize":
            return <NativeMinimize/>;
        case "Maximize":
            return <NativeMaximize/>;
        case "Close":
        return <NativeClose/>;
    }
}

function NativeMinimize() {
    switch (osType) {
        case "linux":
            return <LinuxMinimize/>;
        case "macos":
            return <MacosMinimize/>;
        case "windows":
            return <WindowsMinimize/>;
    }
}

function NativeMaximize() {
    switch (osType) {
        case "linux":
            return <LinuxMaximize/>;
        case "macos":
            return <MacosMaximize/>;
        case "windows":
            return <WindowsMaximize/>;
    }
}

function NativeClose() {
    switch (osType) {
        case "linux":
            return <LinuxClose/>;
        case "macos":
            return <MacosClose/>;
        case "windows":
            return <WindowsClose/>;
    }
}

function LinuxControl({
    "aria-label": ariaLabel,
    onClick,
    children,
}: {
    "aria-label": string;
    onClick: () => void;
    children: React.ReactNode;
}) {
    return (
        <RACButton
            aria-label={ariaLabel}
            onClick={onClick}
            className="flex size-5 mx-1 shrink-0 items-center justify-center bg-fg/4 rounded-full text-navbar-fg opacity-80 
                transition-colors hover:opacity-100 hover:bg-fg/8 focus:outline-none focus-visible:ring-2 focus-visible:ring-inset 
                focus-visible:ring-primary/50 pressed:bg-fg/12 fill-current"
        >
            {children}
        </RACButton>
    );
}

function LinuxMinimize() {
    return (
        <LinuxControl
            aria-label="Minimize"
            onClick={() => getCurrentWindow().minimize()}
        >
            <WindowMinimizeSymbolic className="size-3.5 shrink-0" />
        </LinuxControl>
    );
}

function LinuxMaximize() {
    const { isMaximized } = useIsMaximized();
    return (
        <LinuxControl
            aria-label="Maximize"
            onClick={() => getCurrentWindow().toggleMaximize()}
        >
            {isMaximized 
                ? <WindowRestoreSymbolic className="size-3.5 shrink-0" /> 
                : <WindowMaximizeSymbolic className="size-3.5 shrink-0" />}
        </LinuxControl>
    );
}

function LinuxClose() {
    return (
        <LinuxControl
            aria-label="Close"
            onClick={() => getCurrentWindow().close()}
        >
            {/* <img src={windowCloseSymbolic} alt="Minimize" className="size-3.5 shrink-0" /> */}
            <WindowCloseSymbolic className="size-3.5 shrink-0" />
        </LinuxControl>
    );
}

type MacosControlColor = "red" | "yellow" | "green";

const macosDotClasses: Record<MacosControlColor, string> = {
    red: "bg-[#ff5f57] border-[#e0443e]",
    yellow: "bg-[#febc2e] border-[#dea123]",
    green: "bg-[#28c840] border-[#1aab29]",
};

function MacosControl({
    "aria-label": ariaLabel,
    onClick,
    color,
    children,
}: {
    "aria-label": string;
    onClick: () => void;
    color: MacosControlColor;
    children: React.ReactNode;
}) {
    return (
        <RACButton
            aria-label={ariaLabel}
            onClick={onClick}
            className="group relative flex size-4 shrink-0 items-center justify-center focus:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-primary/50 pressed:opacity-90"
        >
            <span
                className={[
                    "size-3 rounded-full border shadow-[inset_0_1px_0_rgba(255,255,255,0.35)] transition-[filter] group-hover:brightness-105 pressed:brightness-95",
                    macosDotClasses[color],
                ].join(" ")}
            />
            <span className="pointer-events-none absolute inset-0 flex items-center justify-center text-black/70 opacity-0 transition-opacity group-hover:opacity-100">
                {children}
            </span>
        </RACButton>
    );
}

function MacosGlyphMinus() {
    return (
        <span
            aria-hidden="true"
            className="h-[1.5px] w-2 rounded-full bg-black/70"
        />
    );
}

function MacosGlyphPlus() {
    return (
        <span aria-hidden="true" className="relative size-2">
            <span className="absolute inset-x-0 top-1/2 h-[1.5px] -translate-y-1/2 rounded-full bg-black/70" />
            <span className="absolute inset-y-0 left-1/2 w-[1.5px] -translate-x-1/2 rounded-full bg-black/70" />
        </span>
    );
}

function MacosGlyphClose() {
    return (
        <span aria-hidden="true" className="relative size-2">
            <span className="absolute inset-x-0 top-1/2 h-[1.5px] -translate-y-1/2 rotate-45 rounded-full bg-black/70" />
            <span className="absolute inset-x-0 top-1/2 h-[1.5px] -translate-y-1/2 -rotate-45 rounded-full bg-black/70" />
        </span>
    );
}

function MacosMinimize() {
    return (
        <MacosControl
            aria-label="Minimize"
            color="yellow"
            onClick={() => getCurrentWindow().minimize()}
        >
            <MacosGlyphMinus />
        </MacosControl>
    );
}

function MacosMaximize() {
    return (
        <MacosControl
            aria-label="Maximize"
            color="green"
            onClick={() => getCurrentWindow().toggleMaximize()}
        >
            <MacosGlyphPlus />
        </MacosControl>
    );
}

function MacosClose() {
    return (
        <MacosControl
            aria-label="Close"
            color="red"
            onClick={() => getCurrentWindow().close()}
        >
            <MacosGlyphClose />
        </MacosControl>
    );
}

function WindowsMinimize() {
    return <div>WindowsMinimize</div>;
}

function WindowsMaximize() {
    return <div>WindowsMaximize</div>;
}

function WindowsClose() {
    return <div>WindowsClose</div>;
}
