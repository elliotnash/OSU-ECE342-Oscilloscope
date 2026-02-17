import { Button } from "~/components/button";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useState, useCallback, useEffect, useRef } from "react";

import { extent } from '@visx/vendor/d3-array';
import { scaleLinear } from '@visx/scale';
import ReactECharts from "echarts-for-react";
import type { ScopeChannel, FrameData } from "~/bindings";
import { Titlebar } from "~/components/titlebar";
import { Bars3Icon } from "@heroicons/react/24/solid";
import { Menu, MenuContent, MenuItem, MenuTrigger } from "~/components/menu";
import { Card, CardContent, CardHeader, CardTitle } from "~/components/card";
import { Select, SelectContent, SelectItem, SelectTrigger } from "~/components/select";
import { ToggleGroup, ToggleGroupItem } from "~/components/toggle-group";
import type { Key } from "react-aria-components";
import { Label } from "~/components/field";
import { ScrollArea } from "~/components/scroll-area";
import { Switch } from "~/components/switch";
import { Tabs, Tab, TabList, TabPanel } from "~/components/tabs";
import { Input } from "~/components/input";

export const Route = createFileRoute('/home')({
  component: Index,
})

function Index() {
  return (
    <>
      <Titlebar menuButton={
        <Menu>
          <MenuTrigger>
            <Button size="sq-sm" intent="outline">
              <Bars3Icon/>
            </Button>
          </MenuTrigger>
          <MenuContent>
            <MenuItem>
              <Link to="/test">Settings</Link>
            </MenuItem>
            <MenuItem>
              <Link to="/test">About</Link>
            </MenuItem>
            <MenuItem>
              <Link to="/test">Test Panel</Link>
            </MenuItem>
          </MenuContent>
        </Menu>
      }/>
      <div className="flex-1 min-h-0 overflow-auto flex flex-col landscape:flex-row p-4 gap-4 landscape:gap-6">
        <div className="flex-1 flex flex-col min-w-0 min-h-0 w-full h-full overflow-hidden">
          <div className="flex-1 min-w-0 min-h-0 w-full h-full flex">
            <Plot/>
          </div>
          <div className="bg-secondary/25 border rounded-xl p-4"></div>
        </div>
          <ScrollArea scrollFade className="landscape:w-max portrait:h-max bg-secondary/25 border rounded-xl">
            <div className="flex flex-row p-4 landscape:flex-col w-max h-max gap-4">
              <ControlPanel />
            </div>
          </ScrollArea>
        {/* </div> */}
      </div>
    </>
   
  );
}

function ControlPanel() {
  return (
    <>
      <ChannelCard channel="A" />
      <ChannelCard channel="B" />
      <CommondCard />
      <MathChannelCard />
    </>
  )
}

const mathChannelPresets = [
  { id: "1", value: "CHA + CHB" },
  { id: "2", value: "CHA - CHB" },
  { id: "3", value: "CHA * CHB" },
  { id: "4", value: "CHA / CHB" },
]

function MathChannelCard() {
  const [enabled, setEnabled] = useState(true);
  const [isPreset, setIsPreset] = useState(true);
  const [preset, setPreset] = useState(mathChannelPresets[0]);
  const [customExpression, setCustomExpression] = useState("");

  const handlePresetChange = useCallback((key: Key | null) => {
    if (key) {
      const newPreset = mathChannelPresets.find((option) => option.id === key) ?? mathChannelPresets[0];
      setPreset(newPreset);
    }
  }, []);

  return (
    <Card className="h-auto landscape:w-full min-w-0 gap-2">
      <CardHeader>
        <CardTitle className="flex flex-row w-full justify-between">
          Math Channel <Switch isSelected={enabled} onChange={setEnabled}/>
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex flex-col gap-2">
          <Tabs isDisabled={!enabled} className="w-full mt-[-8pt]" onSelectionChange={(tab) => setIsPreset(tab === "preset")}>
            <TabList >
              <Tab id="preset">Preset</Tab>
              <Tab id="custom">Custom</Tab>
            </TabList>
            <TabPanel id="preset">
              <div className="grid min-w-0 w-full *:col-start-1 *:row-start-1">
                <Select value={preset.id} onChange={handlePresetChange}>
                  <SelectTrigger />
                  <SelectContent items={mathChannelPresets}>
                    {(item) => <SelectItem id={item.id} textValue={item.value}>{item.value}</SelectItem>}
                  </SelectContent>
                </Select>
                {/* Invisible copy so grid cell is at least as wide as the Input */}
                <div className="invisible pointer-events-none w-fit **:data-[slot=control]:w-max!">
                  <Input value={customExpression} onChange={(e) => setCustomExpression(e.target.value)} />
                </div>
              </div>
            </TabPanel>
            <TabPanel id="custom">
              <div className="grid min-w-0 w-full *:col-start-1 *:row-start-1">
                {/* Invisible copy so grid cell is at least as wide as the Select */}
                <div className="invisible pointer-events-none w-fit">
                  <Select value={preset.id} onChange={handlePresetChange}>
                    <SelectTrigger />
                    <SelectContent items={mathChannelPresets}>
                      {(item) => <SelectItem id={item.id} textValue={item.value}>{item.value}</SelectItem>}
                    </SelectContent>
                  </Select>
                </div>
                <div className="min-w-0 overflow-hidden">
                  <Input value={customExpression} onChange={(e) => setCustomExpression(e.target.value)} />
                </div>
              </div>
            </TabPanel>
          </Tabs>
        </div>
      </CardContent>
    </Card>
  )
}

const sampleRateOptions = [
  { id: "1", value: 250_000, label: "250 kHz" },
  { id: "2", value: 200_000, label: "200 kHz" },
  { id: "3", value: 150_000, label: "150 kHz" },
  { id: "4", value: 100_000, label: "100 kHz" },
  { id: "5", value: 75_000, label: "75 kHz" },
  { id: "6", value: 50_000, label: "50 kHz" },
  { id: "7", value: 25_000, label: "25 kHz" },
  { id: "8", value: 10_000, label: "10 kHz" },
]

function CommondCard() {
  const [sampleRate, setSampleRate] = useState(sampleRateOptions[0]);
  const handleSampleRateChange = useCallback((key: Key | null) => {
    if (key) {
      const newSampleRate = sampleRateOptions.find((option) => option.id === key) ?? sampleRateOptions[0];
      setSampleRate(newSampleRate);
      // TODO: Dispatch tauri event to set sample rate on hardware
    }
  }, []);

  return (
    <Card className="h-auto landscape:w-full gap-2">
      <CardHeader>
        <CardTitle>All Channels</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex flex-col gap-2">
          <div className="flex flex-row gap-4">
            <div className="w-full">
              <Label>Sample Rate</Label>
              <Select value={sampleRate.id} onChange={handleSampleRateChange}>
                <SelectTrigger />
                <SelectContent items={sampleRateOptions}>
                  {(item) => <SelectItem id={item.id} textValue={item.label}>{item.label}</SelectItem>}
                </SelectContent>
              </Select>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

const voltageScaleOptions = [
  { id: "1", value: 1.5 },
  { id: "2", value: 0.36 },
  { id: "3", value: 0.07 },
]

function ChannelCard({ channel }: { channel: ScopeChannel }) {
  const [voltageScale, setVoltageScale] = useState(voltageScaleOptions[0]);
  const [coupling, setCoupling] = useState<Key>("DC");
  const [attenuation, setAttenuation] = useState<Key>("1x");
  const [enabled, setEnabled] = useState(true);

  const handleVoltageScaleChange = useCallback((key: Key | null) => {
      if (key) {
        const newScale = voltageScaleOptions.find((option) => option.id === key) ?? voltageScaleOptions[0];
        setVoltageScale(newScale);
        // TODO: Dispatch tauri event to set voltage scale on hardware
      }
  }, []);

  const handleCouplingChange = useCallback((keys: Set<Key>) => {
    if (keys.size > 0) {
      const newCoupling = keys.values().next().value;
      if (newCoupling) {
        setCoupling(newCoupling);
        // TODO: Dispatch tauri event to set coupling on hardware
      }
    }
  }, []);

  const handleAttenuationChange = useCallback((keys: Set<Key>) => {
    if (keys.size > 0) {
      const newAttenuation = keys.values().next().value;
      if (newAttenuation) {
        setAttenuation(newAttenuation);
        // TODO: Dispatch tauri event to set coupling on hardware
      }
    }
  }, []);

  return (
    <Card className="h-auto landscape:w-full gap-2">
      <CardHeader>
        <CardTitle className="flex flex-row w-full justify-between">
          Channel {channel} <Switch isSelected={enabled} onChange={setEnabled}/>
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex flex-col gap-2">
          <div>
            <Label>Voltage Scale</Label>
            <Select isDisabled={!enabled} key={`voltage-scale-${attenuation}`} value={voltageScale.id} onChange={handleVoltageScaleChange}>
              <SelectTrigger />
              <SelectContent items={voltageScaleOptions}>
                {(item) => (
                  <SelectItem id={item.id} textValue={`\u00B1${attenuation === "1x" ? item.value : parseFloat((item.value * 10).toFixed(2))}V`}>
                    {`\u00B1${attenuation === "1x" ? item.value : parseFloat((item.value * 10).toFixed(2))}V`}
                  </SelectItem>
                )}
              </SelectContent>
            </Select>
          </div>
          <div className="flex flex-row gap-4 justify-between">
            <div className="flex flex-col">
              <Label>Coupling</Label>
              <ToggleGroup isDisabled={!enabled} selectedKeys={[coupling]} onSelectionChange={handleCouplingChange}>
                <ToggleGroupItem id="DC">DC</ToggleGroupItem>
                <ToggleGroupItem id="AC">AC</ToggleGroupItem>
              </ToggleGroup>
            </div>
            <div className="flex flex-col">
              <Label>Attenuation</Label>
              <ToggleGroup isDisabled={!enabled} selectedKeys={[attenuation]} onSelectionChange={handleAttenuationChange}>
                <ToggleGroupItem id="1x">1x</ToggleGroupItem>
                <ToggleGroupItem id="10x">10x</ToggleGroupItem>
              </ToggleGroup>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
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
  voltage_scale: 3.0,
  channel: "A",
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

// Align domain to grid: extend data range so both ends fall exactly on grid lines.
// Returns [domainMin, domainMax] and the step used (for drawing grid lines).
function alignDomainToGrid(
  dataMin: number,
  dataMax: number,
  approximateDivisions: number = 10
): { domain: [number, number]; step: number } {
  const range = dataMax - dataMin;
  if (range <= 0) return { domain: [dataMin, dataMax], step: range || 1 };
  const tempScale = scaleLinear<number>({ domain: [dataMin, dataMax], range: [0, 1] });
  const ticks = tempScale.ticks(approximateDivisions);
  const step = ticks.length >= 2 ? ticks[1] - ticks[0] : range / approximateDivisions;
  if (step <= 0) return { domain: [dataMin, dataMax], step: range || 1 };
  const domainMin = Math.floor(dataMin / step) * step;
  const domainMax = Math.ceil(dataMax / step) * step;
  return { domain: [domainMin, domainMax], step };
}

export default function Plot() {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [chartTheme, setChartTheme] = useState({
    bg: "transparent",
    card: "rgba(255, 255, 255, 0.05)",
    axisLabel: "rgba(255, 255, 255, 0.7)",
    axisLine: "rgba(255, 255, 255, 0.7)",
    gridLine: "rgba(255, 255, 255, 0.1)",
    series: "rgb(96, 165, 250)",
  });

  useEffect(() => {
    if (!containerRef.current) return;
    const styles = getComputedStyle(containerRef.current);

    const bg = styles.getPropertyValue("--bg").trim();
    const fg = styles.getPropertyValue("--fg").trim();
    const border = styles.getPropertyValue("--border").trim();
    const primary = styles.getPropertyValue("--primary").trim();
    const secondary = styles.getPropertyValue("--secondary").trim();

    setChartTheme((prev) => ({
      bg: bg || prev.bg,
      card: `color-mix(in oklch, ${bg}, ${secondary} 25%)` || prev.card,
      axisLabel: fg || prev.axisLabel,
      axisLine: `oklch(from ${fg} l c h / 0.3)` || prev.axisLine,
      gridLine: border || prev.gridLine,
      series: primary || prev.series,
    }));
  }, []);

  const axisPadding = { top: 20, right: 20, bottom: 20, left: 20 };

  const xDataExtent = extent(plotData, getX) as [number, number];
  const yMin = Math.min(...plotData.map(getY));
  const yMax = Math.max(...plotData.map(getY));
  const { domain: xDomain, step: xStep } = alignDomainToGrid(xDataExtent[0], xDataExtent[1]);
  const { domain: yDomain, step: yStep } = alignDomainToGrid(yMin, yMax);

  const option = {
    animation: false,
    backgroundColor: chartTheme.bg,
    grid: {
      top: axisPadding.top,
      right: axisPadding.right,
      bottom: axisPadding.bottom,
      left: axisPadding.left,
      containLabel: false,
    },
    tooltip: {
      trigger: "axis",
      axisPointer: {
        type: "cross",
        lineStyle: {
          color: chartTheme.axisLine,
        },
        label: {
          backgroundColor: chartTheme.card,
          borderColor: chartTheme.gridLine,
          borderWidth: 1,
          color: chartTheme.axisLabel,
        },
      },
      backgroundColor: chartTheme.card,
      borderColor: chartTheme.gridLine,
      borderWidth: 1,
      textStyle: {
        color: chartTheme.axisLabel,
      },
      formatter: (params: any) => {
        const items = Array.isArray(params) ? params : [params];
        if (!items.length) return "";

        const xRaw = items[0].axisValue;
        const x =
          typeof xRaw === "number" && Number.isFinite(xRaw)
            ? Number(xRaw.toPrecision(4))
            : xRaw;

        const lines = [
          `<div>t: ${x}</div>`,
          ...items.map((item) => {
            const yRaw = item.value?.[1] ?? item.value;
            const y =
              typeof yRaw === "number" && Number.isFinite(yRaw)
                ? Number(yRaw.toPrecision(4))
                : yRaw;
            const markerColor = chartTheme.series;
            const marker = `<span style="display:inline-block;width:10px;height:10px;border-radius:50%;background-color:${markerColor};margin-right:4px;"></span>`;
            return `<div>${marker} ${y}V</div>`;
          }),
        ];

        return lines.join("");
      },
    },
    xAxis: {
      type: "value",
      min: xDomain[0],
      max: xDomain[1],
      interval: xStep,
      axisLine: {
        lineStyle: {
          color: chartTheme.axisLine,
        },
      },
      axisLabel: {
        color: chartTheme.axisLabel,
        formatter: (value: number) => {
          if (!Number.isFinite(value)) return "";
          // 4 significant figures, avoid floating-point noise
          return Number(value.toPrecision(4)).toString();
        },
      },
      axisPointer: {
        lineStyle: {
          color: chartTheme.axisLine,
        },
        label: {
          formatter: (params: any) => {
            const value = params.value;
            if (typeof value === "number" && Number.isFinite(value)) {
              return Number(value.toPrecision(4)).toString();
            }
            return value?.toString() || "";
          },
        },
      },
      splitLine: {
        show: true,
        lineStyle: {
          color: chartTheme.gridLine,
          width: 1,
        },
      },
    },
    yAxis: {
      type: "value",
      min: yDomain[0],
      max: yDomain[1],
      interval: yStep,
      axisLine: {
        lineStyle: {
          color: chartTheme.axisLine,
        },
      },
      axisLabel: {
        color: chartTheme.axisLabel,
        formatter: (value: number) => {
          if (!Number.isFinite(value)) return "";
          // 4 significant figures, avoid floating-point noise like 0.9999999999
          return Number(value.toPrecision(4)).toString();
        },
      },
      axisPointer: {
        lineStyle: {
          color: chartTheme.axisLine,
        },
        label: {
          formatter: (params: any) => {
            const value = params.value;
            if (typeof value === "number" && Number.isFinite(value)) {
              return Number(value.toPrecision(4)).toString();
            }
            return value?.toString() || "";
          },
        },
      },
      splitLine: {
        show: true,
        lineStyle: {
          color: chartTheme.gridLine,
          width: 1,
        },
      },
    },
    series: [
      {
        type: "line",
        data: plotData.map((point) => [point.x, point.y]),
        showSymbol: false,
        lineStyle: {
          color: chartTheme.series,
          width: 2,
        },
      },
    ],
  };

  return (
    <div ref={containerRef} className="relative w-full h-full pb-4">
      {/* <div className="bg-red-500 absolute top-0 right-0 z-10">THIS WILL BE A MINIMAP</div> */}
      <ReactECharts
        style={{ width: "100%", height: "100%" }}
        option={option}
        notMerge={true}
        lazyUpdate={true}
      />
    </div>
  );
}
