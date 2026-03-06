import { useCallback, useLayoutEffect, useRef, useState } from "react";
import { twMerge } from "tailwind-merge";

const HANDLE_SIZE = 12;
const HANDLE_HIT_RADIUS = HANDLE_SIZE / 2;

type DragMode = "min" | "max" | "pan" | null;

export function RangeScaleSlider({
  orientation = "vertical",
  fullMin,
  fullMax,
  minRange,
  min,
  max,
  onChange,
  color = "rgb(190, 114, 250)",
  disabled = false,
  className,
  ariaLabel,
}: {
  orientation?: "vertical" | "horizontal";
  fullMin: number;
  fullMax: number;
  minRange: number;
  min: number;
  max: number;
  onChange: (min: number, max: number) => void;
  color?: string;
  disabled?: boolean;
  className?: string;
  ariaLabel?: string;
}) {
  const trackRef = useRef<HTMLDivElement>(null);
  const [trackSize, setTrackSize] = useState(200);
  const [dragMode, setDragMode] = useState<DragMode>(null);
  const lastPosRef = useRef(0);
  const lastMinRef = useRef(min);
  const lastMaxRef = useRef(max);

  const isVertical = orientation === "vertical";

  useLayoutEffect(() => {
    const el = trackRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => {
      setTrackSize(isVertical ? el.clientHeight : el.clientWidth);
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, [isVertical]);

  const valueToPosition = useCallback(
    (value: number) => {
      const t = isVertical
        ? (fullMax - value) / (fullMax - fullMin)
        : (value - fullMin) / (fullMax - fullMin);
      const clamped = Math.max(0, Math.min(1, t));
      return clamped * trackSize;
    },
    [fullMin, fullMax, trackSize, isVertical],
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
      const pos = isVertical ? e.clientY - rect.top : e.clientX - rect.left;
      lastPosRef.current = pos;
      lastMinRef.current = min;
      lastMaxRef.current = max;

      const minPos = valueToPosition(min);
      const maxPos = valueToPosition(max);

      if (isVertical) {
        const minY = valueToPosition(max);
        const maxY = valueToPosition(min);
        if (pos >= maxY - HANDLE_HIT_RADIUS) {
          setDragMode("min");
        } else if (pos <= minY + HANDLE_HIT_RADIUS) {
          setDragMode("max");
        } else if (pos >= minY && pos <= maxY) {
          setDragMode("pan");
        }
      } else {
        if (pos <= minPos + HANDLE_HIT_RADIUS) {
          setDragMode("min");
        } else if (pos >= maxPos - HANDLE_HIT_RADIUS) {
          setDragMode("max");
        } else if (pos >= minPos && pos <= maxPos) {
          setDragMode("pan");
        }
      }
      (e.target as HTMLElement).setPointerCapture(e.pointerId);
    },
    [disabled, min, max, valueToPosition, isVertical],
  );

  const handlePointerMove = useCallback(
    (e: React.PointerEvent) => {
      if (dragMode === null) return;
      const track = trackRef.current;
      if (!track) return;
      const rect = track.getBoundingClientRect();
      const pos = isVertical ? e.clientY - rect.top : e.clientX - rect.left;
      const deltaPos = pos - lastPosRef.current;
      lastPosRef.current = pos;

      const deltaValue = (deltaPos / trackSize) * (fullMax - fullMin);

      if (isVertical) {
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
      } else {
        if (dragMode === "min") {
          const newMin = lastMinRef.current + deltaValue;
          const newMax = lastMaxRef.current;
          const [clampedMin, clampedMax] = clampRange(newMin, newMax);
          lastMinRef.current = clampedMin;
          lastMaxRef.current = clampedMax;
          onChange(clampedMin, clampedMax);
        } else if (dragMode === "max") {
          const newMin = lastMinRef.current;
          const newMax = lastMaxRef.current + deltaValue;
          const [clampedMin, clampedMax] = clampRange(newMin, newMax);
          lastMinRef.current = clampedMin;
          lastMaxRef.current = clampedMax;
          onChange(clampedMin, clampedMax);
        } else if (dragMode === "pan") {
          const newMin = lastMinRef.current + deltaValue;
          const newMax = lastMaxRef.current + deltaValue;
          const [clampedMin, clampedMax] = clampRange(newMin, newMax);
          lastMinRef.current = clampedMin;
          lastMaxRef.current = clampedMax;
          onChange(clampedMin, clampedMax);
        }
      }
    },
    [dragMode, onChange, clampRange, fullMin, fullMax, trackSize, isVertical],
  );

  const handlePointerUp = useCallback(
    (e: React.PointerEvent) => {
      (e.target as HTMLElement).releasePointerCapture(e.pointerId);
      setDragMode(null);
    },
    [],
  );

  const minPos = valueToPosition(min);
  const maxPos = valueToPosition(max);

  const fillStyle = isVertical
    ? {
        left: 0,
        right: 0,
        top: Math.min(minPos, maxPos),
        height: Math.max(2, Math.abs(maxPos - minPos)),
      }
    : {
        top: 0,
        bottom: 0,
        left: minPos,
        width: Math.max(2, maxPos - minPos),
      };

  const minHandleStyle = isVertical
    ? { top: minPos - HANDLE_SIZE / 2 }
    : { left: minPos - HANDLE_SIZE / 2 };
  const maxHandleStyle = isVertical
    ? { top: maxPos - HANDLE_SIZE / 2 }
    : { left: maxPos - HANDLE_SIZE / 2 };

  return (
    <div
      className={twMerge(
        "flex min-h-0 min-w-0",
        isVertical ? "flex-1 flex-col items-center" : "flex-1 flex-row items-center",
        className,
      )}
    >
      <div
        ref={trackRef}
        role="slider"
        aria-valuemin={fullMin}
        aria-valuemax={fullMax}
        aria-valuenow={min}
        aria-label={ariaLabel}
        tabIndex={disabled ? -1 : 0}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
        className={twMerge(
          "relative rounded-lg border border-border bg-secondary/30",
          "touch-none select-none",
          isVertical ? "w-4 flex-1 min-h-0" : "h-4 flex-1 min-w-0",
          disabled ? "opacity-50 pointer-events-none" : "cursor-grab active:cursor-grabbing",
        )}
      >
        <div
          className="absolute rounded-md transition-opacity"
          style={{
            ...fillStyle,
            backgroundColor: color,
            opacity: 0.4,
          }}
        />
        <div
          className="absolute rounded-full border-2 border-white shadow-sm"
          style={{
            ...minHandleStyle,
            width: HANDLE_SIZE,
            height: HANDLE_SIZE,
            backgroundColor: color,
            ...(isVertical ? { left: "50%", transform: "translateX(-50%)" } : { top: "50%", transform: "translateY(-50%)" }),
          }}
          aria-hidden
        />
        <div
          className="absolute rounded-full border-2 border-white shadow-sm"
          style={{
            ...maxHandleStyle,
            width: HANDLE_SIZE,
            height: HANDLE_SIZE,
            backgroundColor: color,
            ...(isVertical ? { left: "50%", transform: "translateX(-50%)" } : { top: "50%", transform: "translateY(-50%)" }),
          }}
          aria-hidden
        />
      </div>
    </div>
  );
}
