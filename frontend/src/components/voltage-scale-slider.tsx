import { useCallback, useLayoutEffect, useRef, useState } from "react";
import { twMerge } from "tailwind-merge";
import type { ScopeChannel } from "~/bindings";

const HANDLE_SIZE = 12;
const HANDLE_HIT_RADIUS = HANDLE_SIZE / 2;

type DragMode = "min" | "max" | "pan" | null;

const DEFAULT_VOLTAGE_SCALE = 1.5;

export function VoltageScaleSlider({
  channel,
  voltageScale = DEFAULT_VOLTAGE_SCALE,
  min,
  max,
  onChange,
  color = "rgb(190, 114, 250)",
  disabled = false,
  className,
}: {
  channel: ScopeChannel;
  voltageScale?: number;
  min: number;
  max: number;
  onChange: (min: number, max: number) => void;
  color?: string;
  disabled?: boolean;
  className?: string;
}) {
  const trackRef = useRef<HTMLDivElement>(null);
  const [trackHeight, setTrackHeight] = useState(200);
  const [dragMode, setDragMode] = useState<DragMode>(null);
  const lastYRef = useRef(0);
  const lastMinRef = useRef(min);
  const lastMaxRef = useRef(max);

  useLayoutEffect(() => {
    const el = trackRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setTrackHeight(el.clientHeight));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const vs = voltageScale > 0 ? voltageScale : DEFAULT_VOLTAGE_SCALE;
  const fullMin = -vs / 2;
  const fullMax = vs / 2;
  const minRange = vs / 20;

  const valueToY = useCallback(
    (value: number) => {
      const t = (fullMax - value) / (fullMax - fullMin);
      return Math.max(0, Math.min(1, t)) * trackHeight;
    },
    [fullMin, fullMax, trackHeight],
  );

  const clampRange = useCallback(
    (newMin: number, newMax: number) => {
      const lo = Math.max(fullMin, Math.min(newMin, newMax - minRange));
      const hi = Math.min(fullMax, Math.max(newMax, newMin + minRange));
      return [lo, hi] as const;
    },
    [fullMin, fullMax, minRange],
  );

  const handlePointerDown = useCallback(
    (e: React.PointerEvent) => {
      if (disabled) return;
      const track = trackRef.current;
      if (!track) return;
      const rect = track.getBoundingClientRect();
      const y = e.clientY - rect.top;
      lastYRef.current = y;
      lastMinRef.current = min;
      lastMaxRef.current = max;

      const minY = valueToY(max);
      const maxY = valueToY(min);

      // Use bands so pan never wins over handles: bottom band then top band then middle = pan
      if (y >= maxY - HANDLE_HIT_RADIUS) {
        setDragMode("min");
      } else if (y <= minY + HANDLE_HIT_RADIUS) {
        setDragMode("max");
      } else if (y >= minY && y <= maxY) {
        setDragMode("pan");
      }
      (e.target as HTMLElement).setPointerCapture(e.pointerId);
    },
    [disabled, min, max, valueToY],
  );

  const handlePointerMove = useCallback(
    (e: React.PointerEvent) => {
      if (dragMode === null) return;
      const track = trackRef.current;
      if (!track) return;
      const rect = track.getBoundingClientRect();
      const y = e.clientY - rect.top;
      const deltaY = y - lastYRef.current;
      lastYRef.current = y;

      const deltaValue = (deltaY / trackHeight) * (fullMax - fullMin);

      if (dragMode === "max") {
        const newMax = lastMaxRef.current - deltaValue;
        const newMin = lastMinRef.current + deltaValue;
        const [clampedMin, clampedMax] = clampRange(newMin, newMax);
        lastMinRef.current = clampedMin;
        lastMaxRef.current = clampedMax;
        onChange(clampedMin, clampedMax);
      } else if (dragMode === "min") {
        const newMin = lastMinRef.current - deltaValue;
        const newMax = lastMaxRef.current + deltaValue;
        const [clampedMin, clampedMax] = clampRange(newMin, newMax);
        lastMinRef.current = clampedMin;
        lastMaxRef.current = clampedMax;
        onChange(clampedMin, clampedMax);
      } else if (dragMode === "pan") {
        const newMin = lastMinRef.current - deltaValue;
        const newMax = lastMaxRef.current - deltaValue;
        const [clampedMin, clampedMax] = clampRange(newMin, newMax);
        lastMinRef.current = clampedMin;
        lastMaxRef.current = clampedMax;
        onChange(clampedMin, clampedMax);
      }
    },
    [dragMode, onChange, clampRange, fullMin, fullMax, trackHeight],
  );

  const handlePointerUp = useCallback(
    (e: React.PointerEvent) => {
      (e.target as HTMLElement).releasePointerCapture(e.pointerId);
      setDragMode(null);
    },
    [],
  );

  const minY = valueToY(max);
  const maxY = valueToY(min);
  const fillTop = minY;
  const fillHeight = maxY - minY;

  return (
    <div className={twMerge("flex flex-1 flex-col items-center min-h-0 min-w-0", className)}>
      <span className="text-xs font-medium text-fg/80 shrink-0">CH{channel}</span>
      <div
        ref={trackRef}
        role="slider"
        aria-valuemin={fullMin}
        aria-valuemax={fullMax}
        aria-valuenow={min}
        aria-valuetext={`${min.toFixed(2)}V to ${max.toFixed(2)}V`}
        aria-label={`Channel ${channel} voltage scale`}
        tabIndex={disabled ? -1 : 0}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
        className={twMerge(
          "relative w-8 flex-1 min-h-0 rounded-lg border border-border bg-secondary/30",
          "touch-none select-none",
          disabled ? "opacity-50 pointer-events-none" : "cursor-grab active:cursor-grabbing",
        )}
      >
        <div
          className="absolute left-0 right-0 rounded-md transition-opacity"
          style={{
            top: fillTop,
            height: Math.max(2, fillHeight),
            backgroundColor: color,
            opacity: 0.4,
          }}
        />
        <div
          className="absolute left-1/2 -translate-x-1/2 rounded-full border-2 border-white shadow-sm"
          style={{
            top: minY - HANDLE_SIZE / 2,
            width: HANDLE_SIZE,
            height: HANDLE_SIZE,
            backgroundColor: color,
          }}
          aria-hidden
        />
        <div
          className="absolute left-1/2 -translate-x-1/2 rounded-full border-2 border-white shadow-sm"
          style={{
            top: maxY - HANDLE_SIZE / 2,
            width: HANDLE_SIZE,
            height: HANDLE_SIZE,
            backgroundColor: color,
          }}
          aria-hidden
        />
      </div>
    </div>
  );
}
