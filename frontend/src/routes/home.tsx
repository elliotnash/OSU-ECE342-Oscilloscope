import { Button } from "~/components/button";
import "~/styles/global.css";
import { createFileRoute, Link } from "@tanstack/react-router";

import { extent, max } from '@visx/vendor/d3-array';
import * as allCurves from '@visx/curve';
import { Group } from '@visx/group';
import { LinePath } from '@visx/shape';
import { scaleTime, scaleLinear } from '@visx/scale';
import { genDateValue as generateDateValue } from '@visx/mock-data';
import type { DateValue } from "@visx/mock-data/lib/generators/genDateValue";

export const Route = createFileRoute('/home')({
  component: Index,
})

function Index() {
  return (
    <div className="flex-1 min-h-0 overflow-auto flex flex-col items-center justify-center gap-6">
      <h1 className="text-4xl font-semibold text-fg">Oscope Client</h1>
      <Button intent="outline"><Link to="/test">Test Panel</Link></Button>
      <Plot width={600} height={500} />
    </div>
  );
}

const lineData = generateDateValue(25, /* seed= */ 0).sort(
  (a: DateValue, b: DateValue) => a.date.getTime() - b.date.getTime(),
);

// data accessors
const getX = (d: DateValue) => d.date;
const getY = (d: DateValue) => d.value;

// scales
const xScale = scaleTime<number>({
  domain: extent(lineData, getX) as [Date, Date],
});
const yScale = scaleLinear<number>({
  domain: [0, max(lineData, getY) as number],
});

export type CurveProps = {
  width: number;
  height: number;
};

export default function Plot({ width, height }: CurveProps) {
  const svgHeight = height;
  const padding = 20; // padding for top and bottom to prevent clipping

  // update scale output ranges
  xScale.range([0, width - 50]);
  yScale.range([svgHeight - padding, padding]);

  return (
    <div className="visx-curves-demo">
      <svg role="application" aria-label="Oscilloscope Plot" width={width} height={svgHeight}>
        {width > 8 && (
          <Group top={0} left={13}>
            <LinePath<DateValue>
              curve={allCurves.curveStep}
              data={lineData}
              x={(d) => xScale(getX(d)) ?? 0}
              y={(d) => yScale(getY(d)) ?? 0}
              stroke="aqua"
              strokeWidth={2}
              shapeRendering="geometricPrecision"
            />
          </Group>
        )}
      </svg>
    </div>
  );
}