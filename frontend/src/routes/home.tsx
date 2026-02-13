import { Button } from "~/components/button";
import "~/styles/global.css";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useRef, useState, useLayoutEffect } from "react";

import { extent } from '@visx/vendor/d3-array';
import * as allCurves from '@visx/curve';
import { Group } from '@visx/group';
import { LinePath } from '@visx/shape';
import { scaleLinear } from '@visx/scale';
import type { FrameData } from "~/bindings";

export const Route = createFileRoute('/home')({
  component: Index,
})

function Index() {
  const plotContainerRef = useRef<HTMLDivElement>(null);
  const [plotSize, setPlotSize] = useState({ width: 0, height: 0 });

  useLayoutEffect(() => {
    const el = plotContainerRef.current;
    if (!el) return;
    const observer = new ResizeObserver((entries) => {
      const { width, height } = entries[0]?.contentRect ?? { width: 0, height: 0 };
      setPlotSize({ width: Math.round(width), height: Math.round(height) });
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return (
    <div className="flex-1 min-h-0 overflow-auto flex flex-col landscape:flex-row p-4 gap-4 landscape:gap-6">
      <div className="flex-1 flex flex-col">
        <div ref={plotContainerRef} className="flex-1 min-w-0 min-h-0 w-full h-full flex overflow-hidden">
          {plotSize.width > 0 && plotSize.height > 0 && (
            <Plot width={plotSize.width} height={plotSize.height} />
          )}
        </div>
        <div className="bg-secondary/25 border rounded-xl p-4"></div>
      </div>
      <div className="flex flex-row p-4 bg-secondary/25 border rounded-xl landscape:flex-col items-center justify-center gap-4 shrink-0">
        <h1 className="text-4xl font-semibold text-fg">Oscope Client</h1>
        <Button intent="outline"><Link to="/test">Test Panel</Link></Button>
      </div>
    </div>
  );
}

// Generate a sine wave with 1000 data points as 12-bit values (0-4095)
const generateSineWave = (points: number, cycles: number = 2, center: number = 2048): number[] => {
  return Array.from({ length: points }, (_, i) => {
    const sine = Math.sin((2 * Math.PI * cycles * i) / points);
    // Convert sine wave (-1 to 1) to 12-bit value centered around center
    const value = center + (sine * center * 0.8); // Use 80% of center range for amplitude
    return Math.max(0, Math.min(4095, Math.round(value))); // Clamp to 12-bit range
  });
};

const frameData: FrameData = {
  data: generateSineWave(1000, 4, 2048),
  center: 2048,
  timestep_ms: 0.1,
  voltage_scale: 3.0
}

// Convert frameData to plot data points
// Voltage conversion: voltage = (value - center) * (voltage_scale / 4095)
// Time conversion: time = index * timestep_ms
type PlotPoint = { x: number; y: number };
const plotData: PlotPoint[] = frameData.data.map((value, index) => ({
  x: index * frameData.timestep_ms,
  y: (value - frameData.center) * (frameData.voltage_scale / 4095),
}));

// data accessors
const getX = (d: PlotPoint) => d.x;
const getY = (d: PlotPoint) => d.y;

export type CurveProps = {
  width: number;
  height: number;
};

export default function Plot({ width, height }: CurveProps) {
  // const axisPadding = { top: 20, right: 50, bottom: 50, left: 60 };
  const axisPadding = { top: 20, right: 20, bottom: 20, left: 20 };
  const chartWidth = width - axisPadding.left - axisPadding.right;
  const chartHeight = height - axisPadding.top - axisPadding.bottom;

  // scales
  const xScale = scaleLinear<number>({
    domain: extent(plotData, getX) as [number, number],
    range: [0, chartWidth],
  });
  const yScale = scaleLinear<number>({
    domain: [Math.min(...plotData.map(getY)), Math.max(...plotData.map(getY))],
    range: [chartHeight, 0],
  });

  // Generate tick values for axes
  const xTicks = xScale.ticks(10);
  const yTicks = yScale.ticks(8);

  return (
    <svg role="application" aria-label="Oscilloscope Plot" width={width} height={height}>
      {/* Chart area */}
      <Group left={axisPadding.left} top={axisPadding.top}>
        {/* Grid lines */}
        {xTicks.map((tick) => (
          <line
            key={`x-grid-${tick}`}
            x1={xScale(tick)}
            x2={xScale(tick)}
            y1={0}
            y2={chartHeight}
            stroke="rgba(255, 255, 255, 0.1)"
            strokeWidth={1}
          />
        ))}
        {yTicks.map((tick) => (
          <line
            key={`y-grid-${tick}`}
            x1={0}
            x2={chartWidth}
            y1={yScale(tick)}
            y2={yScale(tick)}
            stroke="rgba(255, 255, 255, 0.1)"
            strokeWidth={1}
          />
        ))}

        {/* Data line */}
        {width > 8 && (
          <LinePath<PlotPoint>
            curve={allCurves.curveStep}
            data={plotData}
            x={(d) => xScale(getX(d)) ?? 0}
            y={(d) => yScale(getY(d)) ?? 0}
            stroke="var(--primary)"
            strokeWidth={2}
            shapeRendering="geometricPrecision"
          />
        )}
      </Group>
    </svg>
  );
}