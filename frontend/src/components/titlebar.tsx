import { getCurrentWindow } from "@tauri-apps/api/window";
import { info } from "@tauri-apps/plugin-log";
import { useEffect } from "react";
import { titlebarLayout } from "~/main";
import { Button as RACButton } from "react-aria-components";
import { type } from "@tauri-apps/plugin-os";
import WindowMinimizeSymbolic from "~/assets/adwaita/window-minimize-symbolic.svg?react";
import WindowMaximizeSymbolic from "~/assets/adwaita/window-maximize-symbolic.svg?react";
import WindowRestoreSymbolic from "~/assets/adwaita/window-restore-symbolic.svg?react";
import WindowCloseSymbolic from "~/assets/adwaita/window-close-symbolic.svg?react";
import { useIsMaximized } from "~/hooks/use-is-maximized";
import { commands, type TitlebarButton } from "~/bindings";

const osType = type();

const layout = await commands.getTitlebarLayout();

export function Titlebar({ menuButton }: { menuButton?: React.ReactNode }) {
    useEffect(() => {
        info(JSON.stringify(titlebarLayout));
    }, []);

    return (
        <div data-tauri-drag-region className="relative flex items-center w-full h-10 border-b">
            {/* Left buttons */}
            <div data-tauri-drag-region className="h-full flex items-center flex-1 min-w-0 justify-start">
                {layout.left.map((button) => mapTitlebarButton(button, menuButton))}
            </div>
            <div data-tauri-drag-region className="h-full absolute left-[50vw] -translate-x-1/2 flex items-center gap-2 pointer-events-none">
                <div className="pointer-events-auto flex items-center gap-2 px-2 py-1 text-sm select-none">
                    <h1 data-tauri-drag-region>Oscope Client</h1>
                </div>
            </div>
            {/* Right buttons */}
            <div data-tauri-drag-region className="h-full flex items-center flex-1 min-w-0 justify-end">
                {layout.right.map((button) => mapTitlebarButton(button, menuButton))}
            </div>
        </div>
    )
}

function mapTitlebarButton(button: TitlebarButton, menuButton?: React.ReactNode) {
    switch (button) {
        case "Menu":
            return <div className="px-1">{menuButton}</div>;
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
        case "windows":
            return <WindowsMinimize/>;
    }
}

function NativeMaximize() {
    switch (osType) {
        case "linux":
            return <LinuxMaximize/>;
        case "windows":
            return <WindowsMaximize/>;
    }
}

function NativeClose() {
    switch (osType) {
        case "linux":
            return <LinuxClose/>;
        case "windows":
            return <WindowsClose/>;
    }
}

type ControlProps = {
    "aria-label": string;
    onClick: () => void;
    children: React.ReactNode;
}

function LinuxControl({
    "aria-label": ariaLabel,
    onClick,
    children,
}: ControlProps) {
    return (
        <RACButton
            aria-label={ariaLabel}
            onClick={onClick}
            className="px-2 flex size-5 mx-1 shrink-0 items-center justify-center bg-fg/4 rounded-full text-navbar-fg opacity-80 
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

type WindowsControlProps = ControlProps & {
    variant?: "default" | "close";
};

function WindowsControl({
    "aria-label": ariaLabel,
    onClick,
    children,
    variant = "default",
}: WindowsControlProps) {
    return (
        <RACButton
            aria-label={ariaLabel}
            onClick={onClick}
            className={`
                flex size-[46px] shrink-0 items-center justify-center h-full
                transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-primary/50
                ${variant === "close"
                    ? "text-fg hover:bg-[#E81123] hover:text-white active:bg-[#C50F1F]"
                    : "text-fg hover:bg-black/10 dark:hover:bg-white/10 active:bg-black/20 dark:active:bg-white/20"
                }
            `}
        >
            {children}
        </RACButton>
    );
}

function WindowsMinimizeIcon() {
    return (
        <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor" className="shrink-0">
            <rect x="0" y="4" width="10" height="1" rx="0.5" />
        </svg>
    );
}

function WindowsMaximizeIcon() {
    return (
        <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.25" className="shrink-0">
            <rect x="0.5" y="0.5" width="9" height="9" rx="0.5" />
        </svg>
    );
}

function WindowsRestoreIcon() {
    return (
        <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.25" className="shrink-0">
            <rect x="2" y="0" width="8" height="8" rx="0.5" />
            <rect x="0" y="2" width="8" height="8" rx="0.5" />
        </svg>
    );
}

function WindowsCloseIcon() {
    return (
        <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.25" strokeLinecap="round" className="shrink-0">
            <path d="M1.5 1.5L8.5 8.5M8.5 1.5L1.5 8.5" />
        </svg>
    );
}

function WindowsMinimize() {
    return (
        <WindowsControl
            aria-label="Minimize"
            onClick={() => getCurrentWindow().minimize()}
        >
            <WindowsMinimizeIcon />
        </WindowsControl>
    );
}

function WindowsMaximize() {
    const { isMaximized } = useIsMaximized();
    return (
        <WindowsControl
            aria-label="Maximize"
            onClick={() => getCurrentWindow().toggleMaximize()}
        >
            {isMaximized ? <WindowsRestoreIcon /> : <WindowsMaximizeIcon />}
        </WindowsControl>
    );
}

function WindowsClose() {
    return (
        <WindowsControl
            aria-label="Close"
            onClick={() => getCurrentWindow().close()}
            variant="close"
        >
            <WindowsCloseIcon />
        </WindowsControl>
    );
}
