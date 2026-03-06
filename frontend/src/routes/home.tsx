import { Button } from "~/components/button";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useState, useCallback, useEffect, useRef, forwardRef, useImperativeHandle } from "react";

import { extent } from "@visx/vendor/d3-array";
import { scaleLinear } from "@visx/scale";
import ReactECharts from "echarts-for-react";
import { Channel } from "@tauri-apps/api/core";
import {
  commands,
  type ScopeChannel,
  type FrontendFrameData,
  type ChannelOptions,
  type ScopeGain,
  type ScopeCoupling,
} from "~/bindings";
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

const defaultScale = {
  xDomain: [0, 1] as [number, number],
  yDomain: [-1, 1] as [number, number],
  xStep: 0.1,
  yStep: 0.5,
};

function Index() {
  const plotRef = useRef<{ captureScale: () => void } | null>(null);
  const [channelVisibility, setChannelVisibility] = useState<Record<ScopeChannel, boolean>>({
    A: true,
    B: true,
  });

  const [channelAttenuation, setChannelAttenuation] = useState<Record<ScopeChannel, Key>>({
    A: "1x",
    B: "1x",
  });

  const [mathState, setMathState] = useState<MathState>({
    enabled: false,
    mode: "preset",
    presetId: mathChannelPresets[0]?.id ?? "1",
  });

  const handleChannelEnabledChange = useCallback((channel: ScopeChannel, enabled: boolean) => {
    setChannelVisibility((prev) => ({
      ...prev,
      [channel]: enabled,
    }));
  }, []);

  const handleChannelAttenuationChange = useCallback(
    (channel: ScopeChannel, attenuation: Key) => {
      setChannelAttenuation((prev) => ({
        ...prev,
        [channel]: attenuation,
      }));
    },
    [],
  );

  const handleMathEnabledChange = useCallback((enabled: boolean) => {
    setMathState((prev) => ({ ...prev, enabled }));
  }, []);

  const handleMathModeChange = useCallback((mode: "preset" | "custom") => {
    setMathState((prev) => ({ ...prev, mode }));
  }, []);

  const handleMathPresetChange = useCallback((presetId: string) => {
    setMathState((prev) => ({ ...prev, presetId: presetId as MathPresetId }));
  }, []);

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
            <Plot
              ref={plotRef}
              channelVisibility={channelVisibility}
              channelAttenuation={channelAttenuation}
              mathState={mathState}
            />
          </div>
          <div className="bg-secondary/25 border rounded-xl p-4"></div>
        </div>
          <ScrollArea scrollFade className="landscape:w-max portrait:h-max bg-secondary/25 border rounded-xl">
            <div className="flex flex-row p-4 landscape:flex-col w-max h-max gap-4">
              <ControlPanel
                channelVisibility={channelVisibility}
                channelAttenuation={channelAttenuation}
                onChannelEnabledChange={handleChannelEnabledChange}
                onChannelAttenuationChange={handleChannelAttenuationChange}
                mathState={mathState}
                onMathEnabledChange={handleMathEnabledChange}
                onMathModeChange={handleMathModeChange}
                onMathPresetChange={handleMathPresetChange}
                onAutoScale={() => plotRef.current?.captureScale()}
              />
            </div>
          </ScrollArea>
        {/* </div> */}
      </div>
    </>
   
  );
}

function ControlPanel({
  channelVisibility,
  channelAttenuation,
  onChannelEnabledChange,
  onChannelAttenuationChange,
  mathState,
  onMathEnabledChange,
  onMathModeChange,
  onMathPresetChange,
  onAutoScale,
}: {
  channelVisibility: Record<ScopeChannel, boolean>;
  channelAttenuation: Record<ScopeChannel, Key>;
  onChannelEnabledChange: (channel: ScopeChannel, enabled: boolean) => void;
  onChannelAttenuationChange: (channel: ScopeChannel, attenuation: Key) => void;
  mathState: MathState;
  onMathEnabledChange: (enabled: boolean) => void;
  onMathModeChange: (mode: "preset" | "custom") => void;
  onMathPresetChange: (presetId: string) => void;
  onAutoScale: () => void;
}) {
  return (
    <>
      <ChannelCard
        channel="A"
        enabled={channelVisibility.A}
        attenuation={channelAttenuation.A}
        onEnabledChange={(enabled) => onChannelEnabledChange("A", enabled)}
        onAttenuationChange={(attenuation) =>
          onChannelAttenuationChange("A", attenuation)
        }
      />
      <ChannelCard
        channel="B"
        enabled={channelVisibility.B}
        attenuation={channelAttenuation.B}
        onEnabledChange={(enabled) => onChannelEnabledChange("B", enabled)}
        onAttenuationChange={(attenuation) =>
          onChannelAttenuationChange("B", attenuation)
        }
      />
      <CommondCard onAutoScale={onAutoScale} />
      <MathChannelCard
        state={mathState}
        onEnabledChange={onMathEnabledChange}
        onModeChange={onMathModeChange}
        onPresetChange={onMathPresetChange}
      />
    </>
  )
}

const mathChannelPresets = [
  { id: "1", value: "CHA + CHB" },
  { id: "2", value: "CHA - CHB" },
  { id: "3", value: "CHA * CHB" },
  { id: "4", value: "CHA / CHB" },
] as const;

type MathPresetId = (typeof mathChannelPresets)[number]["id"];

type MathState = {
  enabled: boolean;
  mode: "preset" | "custom";
  presetId: MathPresetId;
};

function MathChannelCard({
  state,
  onEnabledChange,
  onModeChange,
  onPresetChange,
}: {
  state: MathState;
  onEnabledChange: (enabled: boolean) => void;
  onModeChange: (mode: "preset" | "custom") => void;
  onPresetChange: (presetId: MathPresetId) => void;
}) {
  const [customExpression, setCustomExpression] = useState("");

  const handlePresetChange = useCallback(
    (key: Key | null) => {
      if (key) {
        const newPreset =
          mathChannelPresets.find((option) => option.id === key) ??
          mathChannelPresets[0];
        onPresetChange(newPreset.id);
      }
    },
    [onPresetChange],
  );

  return (
    <Card className="h-auto landscape:w-full min-w-0 gap-2">
      <CardHeader>
        <CardTitle className="flex flex-row w-full justify-between">
          Math Channel{" "}
          <Switch
            isSelected={state.enabled}
            onChange={onEnabledChange}
          />
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex flex-col gap-2">
          <Tabs
            isDisabled={!state.enabled}
            className="w-full mt-[-8pt]"
            selectedKey={state.mode}
            onSelectionChange={(key) =>
              onModeChange((key as "preset" | "custom") ?? "preset")
            }
          >
            <TabList >
              <Tab id="preset">Preset</Tab>
              <Tab id="custom">Custom</Tab>
            </TabList>
            <TabPanel id="preset">
              <div className="grid min-w-0 w-full *:col-start-1 *:row-start-1">
                <Select value={state.presetId} onChange={handlePresetChange}>
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
                  <Select value={state.presetId} onChange={handlePresetChange}>
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

function CommondCard({ onAutoScale }: { onAutoScale: () => void }) {
  const [sampleRate, setSampleRate] = useState(sampleRateOptions[0]);
  const handleSampleRateChange = useCallback((key: Key | null) => {
    if (key) {
      const newSampleRate = sampleRateOptions.find((option) => option.id === key) ?? sampleRateOptions[0];
      setSampleRate(newSampleRate);
      void commands.sendSampleRate(newSampleRate.value);
    }
  }, []);

  return (
    <Card className="h-auto landscape:w-full gap-2">
      <CardHeader>
        <CardTitle>All Channels</CardTitle>
      </CardHeader>
      <CardContent className="h-full">
        <div className="flex flex-col gap-2 h-full justify-between">
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
          <Button onPress={onAutoScale}>Auto Scale</Button>
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

function mapVoltageScaleToGain(id: string): ScopeGain {
  switch (id) {
    case "2":
      return "Four";
    case "3":
      return "Twenty";
    case "1":
    default:
      return "One";
  }
}

function ChannelCard({
  channel,
  enabled,
  onEnabledChange,
  attenuation,
  onAttenuationChange,
}: {
  channel: ScopeChannel;
  enabled: boolean;
  onEnabledChange: (enabled: boolean) => void;
  attenuation: Key;
  onAttenuationChange: (attenuation: Key) => void;
}) {
  const [voltageScale, setVoltageScale] = useState(voltageScaleOptions[0]);
  const [coupling, setCoupling] = useState<Key>("DC");

  const dispatchChannelOptions = useCallback(
    (next?: { voltageScaleId?: string; couplingKey?: Key }) => {
      const id = next?.voltageScaleId ?? voltageScale.id;
      const gain: ScopeGain = mapVoltageScaleToGain(id);
      const couplingValue = (next?.couplingKey ?? coupling) as ScopeCoupling;

      const options: ChannelOptions = {
        channel,
        enabled: true,
        voltage_gain: gain,
        coupling: couplingValue,
      };

      void commands.sendChannelOptions(options);
    },
    [channel, voltageScale.id, coupling],
  );

  const handleVoltageScaleChange = useCallback(
    (key: Key | null) => {
      if (key) {
        const newScale =
          voltageScaleOptions.find((option) => option.id === key) ??
          voltageScaleOptions[0];
        setVoltageScale(newScale);
        dispatchChannelOptions({ voltageScaleId: newScale.id });
      }
    },
    [dispatchChannelOptions],
  );

  const handleCouplingChange = useCallback(
    (keys: Set<Key>) => {
      if (keys.size > 0) {
        const newCoupling = keys.values().next().value as Key | undefined;
        if (newCoupling) {
          setCoupling(newCoupling);
          dispatchChannelOptions({ couplingKey: newCoupling });
        }
      }
    },
    [dispatchChannelOptions],
  );

  const handleAttenuationChange = useCallback(
    (keys: Set<Key>) => {
      if (keys.size > 0) {
        const newAttenuation = keys.values().next().value as Key | undefined;
        if (newAttenuation) {
          onAttenuationChange(newAttenuation);
        }
      }
    },
    [onAttenuationChange],
  );

  return (
    <Card className="h-auto landscape:w-full gap-2">
      <CardHeader>
        <CardTitle className="flex flex-row w-full justify-between">
          Channel {channel} <Switch isSelected={enabled} onChange={onEnabledChange}/>
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

type PlotPoint = { x: number; y: number };

// data accessors
const getX = (d: PlotPoint) => d.x;
const getY = (d: PlotPoint) => d.y;

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

type FixedScale = {
  xDomain: [number, number];
  yDomain: [number, number];
  xStep: number;
  yStep: number;
};

export const Plot = forwardRef<{ captureScale: () => void }, {
  channelVisibility: Record<ScopeChannel, boolean>;
  channelAttenuation: Record<ScopeChannel, Key>;
  mathState: MathState;
}>(function Plot(
  { channelVisibility, channelAttenuation, mathState },
  ref,
) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [frames, setFrames] = useState<Partial<Record<ScopeChannel, FrontendFrameData>>>({});
  const latestFramesRef = useRef<Partial<Record<ScopeChannel, FrontendFrameData>>>({});
  const channelVisibilityRef = useRef(channelVisibility);
  const frameTimesRef = useRef<number[]>([]);
  const [frameRate, setFrameRate] = useState(0);
  const [fixedScale, setFixedScale] = useState<FixedScale | null>(null);
  const suggestedScaleRef = useRef<FixedScale | null>(null);
  const initialScaleSetRef = useRef(false);
  const [chartTheme, setChartTheme] = useState({
    bg: "transparent",
    card: "rgba(255, 255, 255, 0.05)",
    axisLabel: "rgba(255, 255, 255, 0.7)",
    axisLine: "rgba(255, 255, 255, 0.7)",
    gridLine: "rgba(255, 255, 255, 0.1)",
    series: {
      A: "rgb(96, 165, 250)",  // blue
      B: "rgb(244, 114, 182)", // pink
    } as Record<ScopeChannel, string>,
  });

  useEffect(() => {
    channelVisibilityRef.current = channelVisibility;
  }, [channelVisibility]);

  useEffect(() => {
    if (!containerRef.current) return;
    const styles = getComputedStyle(containerRef.current);

    const bg = styles.getPropertyValue("--bg").trim();
    const fg = styles.getPropertyValue("--fg").trim();
    const border = styles.getPropertyValue("--border").trim();
    const secondary = styles.getPropertyValue("--secondary").trim();

    setChartTheme((prev) => ({
      bg: bg || prev.bg,
      card: `color-mix(in oklch, ${bg}, ${secondary} 25%)` || prev.card,
      axisLabel: fg || prev.axisLabel,
      axisLine: `oklch(from ${fg} l c h / 0.3)` || prev.axisLine,
      gridLine: border || prev.gridLine,
      series: {
        A: "rgb(190, 114, 250)",
        B: "rgb(244, 50, 100)",
      },
    }));
  }, []);

  useEffect(() => {
    const onEvent = new Channel<FrontendFrameData>();
    onEvent.onmessage = (message) => {
      latestFramesRef.current = {
        ...latestFramesRef.current,
        [message.channel]: message,
      };

      const visibility = channelVisibilityRef.current;
      const bothChannelsVisible = visibility.A && visibility.B;

      const shouldUpdateFrames =
        !bothChannelsVisible || message.channel === "B";

      if (shouldUpdateFrames) {
        setFrames(latestFramesRef.current);
        const now = performance.now();
        const times = frameTimesRef.current;
        times.push(now);
        const cutoff = now - 1000;
        while (times.length > 0 && times[0] < cutoff) {
          times.shift();
        }
        setFrameRate(times.length);
      }
    };
    void commands.receiveFrames(onEvent);

    return () => {
      onEvent.onmessage = () => {};
    }
  }, []);

  const axisPadding = { top: 20, right: 20, bottom: 20, left: 20 };

  const channelOrder: ScopeChannel[] = ["A", "B"];

  const plotDataByChannel = channelOrder.reduce<
    { channel: ScopeChannel; points: PlotPoint[] }[]
  >((acc, channel) => {
    if (!channelVisibility[channel]) return acc;
    const frame = frames[channel];
    if (!frame) return acc;

    const attenuationKey = channelAttenuation[channel];
    const attenuationFactor = attenuationKey === "10x" ? 10 : 1;

    const points: PlotPoint[] = frame.data.map((value, index) => ({
      x: index * frame.timestep_ms,
      y:
        (value - frame.center) *
        (frame.voltage_scale / 4095) *
        attenuationFactor,
    }));
    acc.push({ channel, points });
    return acc;
  }, []);

  const mathColor = "rgb(34, 197, 94)"; // green

  let mathPoints: PlotPoint[] | null = null;
  if (mathState.enabled && mathState.mode === "preset") {
    const a = plotDataByChannel.find((entry) => entry.channel === "A");
    const b = plotDataByChannel.find((entry) => entry.channel === "B");
    if (a && b && a.points.length > 0 && b.points.length > 0) {
      const n = Math.min(a.points.length, b.points.length);
      const pts: PlotPoint[] = [];
      for (let i = 0; i < n; i++) {
        const x = a.points[i].x;
        const ya = a.points[i].y;
        const yb = b.points[i].y;
        let y: number;
        switch (mathState.presetId) {
          case "1": // CHA + CHB
            y = ya + yb;
            break;
          case "2": // CHA - CHB
            y = ya - yb;
            break;
          case "3": // CHA * CHB
            y = ya * yb;
            break;
          case "4": // CHA / CHB
            y = Math.abs(yb) > 1e-9 ? ya / yb : 0;
            break;
          default:
            y = ya;
            break;
        }
        pts.push({ x, y });
      }
      mathPoints = pts;
    }
  }

  const allPoints = [
    ...plotDataByChannel.flatMap((entry) => entry.points),
    ...(mathPoints ?? []),
  ];

  let xDomain: [number, number] = defaultScale.xDomain;
  let yDomain: [number, number] = defaultScale.yDomain;
  let xStep = defaultScale.xStep;
  let yStep = defaultScale.yStep;

  if (allPoints.length > 0) {
    const xDataExtent = extent(allPoints, getX) as [number, number];
    const yMin = Math.min(...allPoints.map(getY));
    const yMax = Math.max(...allPoints.map(getY));
    const xAligned = alignDomainToGrid(xDataExtent[0], xDataExtent[1]);
    const maxAbs = Math.max(Math.abs(yMin), Math.abs(yMax));
    const yAligned =
      maxAbs > 0
        ? alignDomainToGrid(-maxAbs, maxAbs)
        : { domain: yDomain, step: yStep };
    xDomain = xAligned.domain;
    yDomain = yAligned.domain;
    xStep = xAligned.step;
    yStep = yAligned.step;
    suggestedScaleRef.current = { xDomain, yDomain, xStep, yStep };
  } else {
    suggestedScaleRef.current = null;
  }

  // Set initial scale once when we first receive data (suggestedScaleRef is updated in render)
  useEffect(() => {
    if (initialScaleSetRef.current) return;
    const hasData = Object.keys(frames).length > 0;
    if (hasData && suggestedScaleRef.current) {
      setFixedScale(suggestedScaleRef.current);
      initialScaleSetRef.current = true;
    }
  }, [frames]);

  useImperativeHandle(ref, () => ({
    captureScale() {
      if (suggestedScaleRef.current) {
        setFixedScale(suggestedScaleRef.current);
      }
    },
  }), []);

  const scale = fixedScale ?? defaultScale;
  const axisXDomain = scale.xDomain;
  const axisYDomain = scale.yDomain;
  const axisXStep = scale.xStep;
  const axisYStep = scale.yStep;

  // commands

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
      formatter: (params: unknown) => {
        const items = (Array.isArray(params) ? params : [params]) as {
          axisValue: number | string;
          value?: unknown;
        }[];
        if (!items.length) return "";

        const xRaw = items[0].axisValue;
        const x =
          typeof xRaw === "number" && Number.isFinite(xRaw)
            ? Number(xRaw.toPrecision(4))
            : xRaw;

        const lines = [
          `<div>t: ${x}</div>`,
          ...items.map((item) => {
            const raw = item.value as [number, number] | number | undefined;
            const yRaw = Array.isArray(raw) ? raw[1] : raw;
            const y =
              typeof yRaw === "number" && Number.isFinite(yRaw)
                ? Number(yRaw.toPrecision(4))
                : yRaw;
            const seriesName = (item as { seriesName?: string }).seriesName;
            let markerColor = chartTheme.series.A;
            if (seriesName === "Math") {
              markerColor = mathColor;
            } else if (seriesName?.endsWith("B")) {
              markerColor = chartTheme.series.B;
            }
            const marker = `<span style="display:inline-block;width:10px;height:10px;border-radius:50%;background-color:${markerColor};margin-right:4px;"></span>`;
            return `<div>${marker} ${y}V</div>`;
          }),
        ];

        return lines.join("");
      },
    },
    xAxis: {
      type: "value",
      min: axisXDomain[0],
      max: axisXDomain[1],
      interval: axisXStep,
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
          formatter: (params: { value: number | string }) => {
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
      min: axisYDomain[0],
      max: axisYDomain[1],
      interval: axisYStep,
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
          formatter: (params: { value: number | string }) => {
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
      ...channelOrder.map((channel) => {
        const entry = plotDataByChannel.find((e) => e.channel === channel);
        const data = entry
          ? entry.points.map((point) => [point.x, point.y])
          : [];
        return {
          type: "line",
          name: `Channel ${channel}`,
          data,
          showSymbol: false,
          symbol: "none",
          emphasis: { disabled: true },
          lineStyle: {
            color: chartTheme.series[channel],
            width: 2,
          },
        };
      }),
      {
        type: "line",
        name: "Math",
        data: mathPoints ? mathPoints.map((point) => [point.x, point.y]) : [],
        showSymbol: false,
        symbol: "none",
        emphasis: { disabled: true },
        lineStyle: {
          color: mathColor,
          width: 2,
        },
      },
    ],
  };

  return (
    <div ref={containerRef} className="relative w-full h-full pb-4">
      <div className="absolute top-2 left-2 z-10 rounded-md bg-black/60 px-2 py-1 text-xs text-white">
        {`FPS: ${frameRate.toFixed(0)}`}
      </div>
      <ReactECharts
        style={{ width: "100%", height: "100%" }}
        option={option}
        notMerge={false}
        lazyUpdate={true}
      />
    </div>
  );
});
