import { getCurrentWindow } from "@tauri-apps/api/window";
import { info } from "@tauri-apps/plugin-log";
import { useEffect } from "react";
import { titlebarLayout } from "~/main";
import { Button as RACButton } from "react-aria-components";
import { type } from "@tauri-apps/plugin-os";
import { tv } from "tailwind-variants";
import AdwaitaMinimizeSymbolic from "~/assets/adwaita/window-minimize-symbolic.svg?react";
import AdwaitaMaximizeSymbolic from "~/assets/adwaita/window-maximize-symbolic.svg?react";
import AdwaitaRestoreSymbolic from "~/assets/adwaita/window-restore-symbolic.svg?react";
import AdwaitaCloseSymbolic from "~/assets/adwaita/window-close-symbolic.svg?react";
import WindowsMinimizeSvg from "~/assets/windows/windows-minimize.svg?react";
import WindowsMaximizeSvg from "~/assets/windows/windows-maximize.svg?react";
import WindowsRestoreSvg from "~/assets/windows/windows-restore.svg?react";
import WindowsCloseSvg from "~/assets/windows/windows-close.svg?react";
import { useIsMaximized } from "~/hooks/use-is-maximized";
import { commands, type TitlebarButton } from "~/bindings";

const osType = type();

const layout = await commands.getTitlebarLayout();

const titlebarStyles = tv({
    base: "relative flex items-center w-full border-b",
    variants: {
        isLinux: {
            true: "h-12",
            false: "h-10",
        },
    },
});

const menuButtonWrapperStyles = tv({
    base: "",
    variants: {
        isLinux: {
            true: "px-2",
            false: "px-1",
        },
    },
});

export function Titlebar({ menuButton }: { menuButton?: React.ReactNode }) {
    useEffect(() => {
        info(JSON.stringify(titlebarLayout));
    }, []);

    return (
        <div data-tauri-drag-region className={titlebarStyles({ isLinux: osType === "linux" })}>
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
            return <div className={menuButtonWrapperStyles({ isLinux: osType === "linux" })}>{menuButton}</div>;
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
            <AdwaitaMinimizeSymbolic className="size-3.5 shrink-0" />
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
                ? <AdwaitaRestoreSymbolic className="size-3.5 shrink-0" /> 
                : <AdwaitaMaximizeSymbolic className="size-3.5 shrink-0" />}
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
            <AdwaitaCloseSymbolic className="size-3.5 shrink-0" />
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
                    ? "text-fg hover:bg-[#E81123] hover:text-white active:bg-[#C50F1F] rounded-tr-md"
                    : "text-fg hover:bg-black/10 dark:hover:bg-white/10 active:bg-black/20 dark:active:bg-white/20"
                }
            `}
        >
            {children}
        </RACButton>
    );
}

function WindowsMinimize() {
    return (
        <WindowsControl
            aria-label="Minimize"
            onClick={() => getCurrentWindow().minimize()}
        >
            <WindowsMinimizeSvg className="shrink-0" />
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
            {isMaximized ? (
                <WindowsRestoreSvg className="shrink-0" />
            ) : (
                <WindowsMaximizeSvg className="shrink-0" />
            )}
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
            <WindowsCloseSvg className="shrink-0" />
        </WindowsControl>
    );
}
