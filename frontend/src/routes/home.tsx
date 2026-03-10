import { Button } from "~/components/button";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useState, useCallback, useEffect, useRef, forwardRef, useImperativeHandle } from "react";

import { extent } from "@visx/vendor/d3-array";
import { scaleLinear } from "@visx/scale";
import ReactECharts from "echarts-for-react";
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
import { RangeScaleSlider } from "~/components/range-scale-slider";
import { toast } from "sonner";

export const Route = createFileRoute('/home')({
  component: Index,
})

type ChannelStats = {
  name: string;
  color: string;
  amplitude: number;
  center: number;
  stdDev: number;
};

function StatsBar({ stats }: { stats: ChannelStats[] }) {
  if (stats.length === 0) {
    return (
      <div className="bg-secondary/25 border rounded-xl p-4 flex items-center justify-center text-fg/50 text-sm">
        No channels enabled
      </div>
    );
  }
  return (
    <div className="bg-secondary/25 border rounded-xl p-4">
      <div className="flex flex-col gap-2">
        {stats.map((s) => (
          <div
            key={s.name}
            className="flex flex-wrap items-center gap-4 gap-y-1 text-sm"
          >
            <div className="flex items-center gap-2 min-w-22">
              <div
                className="w-3 h-0.5 shrink-0 rounded-full"
                style={{ backgroundColor: s.color }}
              />
              <span className="font-medium text-fg/90">{s.name}</span>
            </div>
            <div className="flex-1 min-w-0 flex justify-evenly gap-6 text-fg/80">
              <span className="shrink-0">
                Amplitude{" "}
                <span className="tabular-nums">{s.amplitude.toPrecision(4)}V</span>
              </span>
              <span className="shrink-0">
                Center{" "}
                <span className="tabular-nums">{s.center.toPrecision(4)}V</span>
              </span>
              <span className="shrink-0">
                Std Dev{" "}
                <span className="tabular-nums">{s.stdDev.toPrecision(4)}V</span>
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

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

  const [channelVoltageScale, setChannelVoltageScale] = useState<
    Record<ScopeChannel, { min: number; max: number }>
  >({
    A: { min: -1, max: 1 },
    B: { min: -1, max: 1 },
  });

  const [channelVoltageScaleConfig, setChannelVoltageScaleConfig] = useState<
    Record<ScopeChannel, number>
  >({ A: 1.5, B: 1.5 });

  const [channelStats, setChannelStats] = useState<ChannelStats[]>([]);
  const handleStatsChange = useCallback((stats: ChannelStats[]) => {
    setChannelStats(stats);
  }, []);

  const [timeScale, setTimeScale] = useState<{ min: number; max: number }>({ min: 0, max: 1 });
  const [timeExtent, setTimeExtent] = useState<{ min: number; max: number } | null>(null);
  const prevTimeExtentRef = useRef<{ min: number; max: number } | null>(null);

  const handleTimeExtent = useCallback((min: number, max: number) => {
    const newExtent = { min, max };
    const newSpan = max - min;
    const prev = prevTimeExtentRef.current;

    setTimeExtent(newExtent);
    prevTimeExtentRef.current = newExtent;

    if (prev === null) {
      if (newSpan > 0) {
        const quarter = newSpan * 0.25;
        setTimeScale({ min: min + quarter, max: max - quarter });
      } else {
        setTimeScale({ min, max });
      }
      return;
    }

    const oldSpan = prev.max - prev.min;
    if (oldSpan <= 0 || newSpan <= 0) return;

    setTimeScale((scale) => {
      const viewportProportion = (scale.max - scale.min) / oldSpan;
      const startProportion = (scale.min - prev.min) / oldSpan;
      const newViewportSpan = viewportProportion * newSpan;
      const newStart = min + startProportion * newSpan;
      const newMin = Math.max(min, Math.min(max - 1e-9, newStart));
      const newMax = Math.max(min + 1e-9, Math.min(max, newStart + newViewportSpan));
      return { min: newMin, max: newMax };
    });
  }, []);

  const handleTimeScaleChange = useCallback((min: number, max: number) => {
    setTimeScale({ min, max });
  }, []);

  useEffect(() => {
    setChannelVoltageScale((prev) => {
      const clampChannel = (ch: ScopeChannel) => {
        const vs = channelVoltageScaleConfig[ch];
        const half = vs > 0 ? vs / 2 : 0.75;
        const minVal = -half;
        const maxVal = half;
        const minRange = vs / 20;
        let newMin = Math.max(minVal, Math.min(prev[ch].min, maxVal - minRange));
        let newMax = Math.min(maxVal, Math.max(prev[ch].max, newMin + minRange));
        if (newMax - newMin < minRange) {
          newMax = Math.min(maxVal, newMin + minRange);
          newMin = Math.max(minVal, newMax - minRange);
        }
        return { min: newMin, max: newMax };
      };
      return { A: clampChannel("A"), B: clampChannel("B") };
    });
  }, [channelVoltageScaleConfig]);

  const handleChannelVoltageScaleChange = useCallback(
    (channel: ScopeChannel, min: number, max: number) => {
      setChannelVoltageScale((prev) => ({
        ...prev,
        [channel]: { min, max },
      }));
    },
    [],
  );

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

  const [triggerPlacingChannel, setTriggerPlacingChannel] = useState<ScopeChannel | null>(null);

  const onSetTriggerPlacing = useCallback((channel: ScopeChannel | null) => {
    setTriggerPlacingChannel(channel);
  }, []);

  const onClearTrigger = useCallback(() => {
    if (triggerPlacingChannel !== null) {
      setTriggerPlacingChannel(null);
    } else {
      void commands.sendTriggerOptions({ channel: "A", enabled: false, value: 0 });
    }
  }, [triggerPlacingChannel]);

  const onTriggerPlaced = useCallback((channel: ScopeChannel, value: number) => {
    void commands.sendTriggerOptions({ channel, enabled: true, value });
    setTriggerPlacingChannel(null);
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
            <div className="flex-1 min-w-0 min-h-0">
              <Plot
                ref={plotRef}
                channelVisibility={channelVisibility}
                channelAttenuation={channelAttenuation}
                mathState={mathState}
                channelVoltageScale={channelVoltageScale}
                onChannelVoltageScaleChange={handleChannelVoltageScaleChange}
                onVoltageScaleFromFrames={setChannelVoltageScaleConfig}
                onStatsChange={handleStatsChange}
                timeScale={timeScale}
                onTimeScaleChange={handleTimeScaleChange}
                onTimeExtent={handleTimeExtent}
                triggerPlacingChannel={triggerPlacingChannel}
                onTriggerPlaced={onTriggerPlaced}
              />
            </div>
            <div className="flex gap-3 items-stretch px-2 py-2 shrink-0 min-h-0">
              <RangeScaleSlider
                orientation="vertical"
                fullMin={-channelVoltageScaleConfig.A / 2}
                fullMax={channelVoltageScaleConfig.A / 2}
                minRange={channelVoltageScaleConfig.A / 20}
                min={channelVoltageScale.A.min}
                max={channelVoltageScale.A.max}
                onChange={(min, max) =>
                  handleChannelVoltageScaleChange("A", min, max)
                }
                color="rgb(190, 114, 250)"
                disabled={!channelVisibility.A}
              />
              <RangeScaleSlider
                orientation="vertical"
                fullMin={-channelVoltageScaleConfig.B / 2}
                fullMax={channelVoltageScaleConfig.B / 2}
                minRange={channelVoltageScaleConfig.B / 20}
                min={channelVoltageScale.B.min}
                max={channelVoltageScale.B.max}
                onChange={(min, max) =>
                  handleChannelVoltageScaleChange("B", min, max)
                }
                color="rgb(244, 50, 100)"
                disabled={!channelVisibility.B}
              />
            </div>
          </div>
          {timeExtent && (
            <div className="flex items-center gap-2 px-2 py-2 shrink-0">
              <RangeScaleSlider
                orientation="horizontal"
                fullMin={timeExtent.min}
                fullMax={timeExtent.max}
                minRange={(timeExtent.max - timeExtent.min) / 20}
                min={timeScale.min}
                max={timeScale.max}
                onChange={handleTimeScaleChange}
                color="oklch(from var(--muted-fg) l c h / 0.25)"
                ariaLabel="Time axis scale"
              />
            </div>
          )}
          <StatsBar stats={channelStats} />
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
                onAutoScale={() => {
                  plotRef.current?.captureScale();
                  if (timeExtent) {
                    const span = timeExtent.max - timeExtent.min;
                    if (span > 0) {
                      const quarter = span * 0.25;
                      setTimeScale({
                        min: timeExtent.min + quarter,
                        max: timeExtent.max - quarter,
                      });
                    }
                  }
                }}
                triggerPlacingChannel={triggerPlacingChannel}
                onSetTriggerPlacing={onSetTriggerPlacing}
                onClearTrigger={onClearTrigger}
              />
            </div>
          </ScrollArea>
        {/* </div> */}
      </div>
    </>
   
  );
}

function TriggerCard({
  triggerPlacingChannel,
  onSetTriggerPlacing,
  onClearTrigger,
}: {
  triggerPlacingChannel: ScopeChannel | null;
  onSetTriggerPlacing: (channel: ScopeChannel | null) => void;
  onClearTrigger: () => void;
}) {
  const handleClear = useCallback(() => {
    onClearTrigger();
  }, [onClearTrigger]);

  const handleSetA = useCallback(() => {
    onSetTriggerPlacing("A");
  }, [onSetTriggerPlacing]);

  const handleSetB = useCallback(() => {
    onSetTriggerPlacing("B");
  }, [onSetTriggerPlacing]);

  useEffect(() => {
    if (triggerPlacingChannel) {
      toast("Click on the graph to set trigger level.");
    }
  }, [triggerPlacingChannel]);

  return (
    <Card className="h-auto landscape:w-full min-w-0 gap-2">
      <CardHeader>
        <CardTitle>Trigger</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex flex-col gap-2">
          <div className="flex flex-wrap flex-col gap-2">
            <Button onPress={handleClear} intent={triggerPlacingChannel ? "secondary" : "outline"}>
              Clear trigger
            </Button>
            <Button
              onPress={handleSetA}
              intent={triggerPlacingChannel === "A" ? "primary" : "outline"}
            >
              Set trigger A
            </Button>
            <Button
              onPress={handleSetB}
              intent={triggerPlacingChannel === "B" ? "primary" : "outline"}
            >
              Set trigger B
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
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
  triggerPlacingChannel,
  onSetTriggerPlacing,
  onClearTrigger,
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
  triggerPlacingChannel: ScopeChannel | null;
  onSetTriggerPlacing: (channel: ScopeChannel | null) => void;
  onClearTrigger: () => void;
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
      <TriggerCard
        triggerPlacingChannel={triggerPlacingChannel}
        onSetTriggerPlacing={onSetTriggerPlacing}
        onClearTrigger={onClearTrigger}
      />
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

// Time axis is in ms; pick metric prefix so tick values are readable (e.g. 10, 20, 30 μs)
const TIME_PREFIXES = [
  { factor: 1e6, unit: "ns" },
  { factor: 1e3, unit: "μs" },
  { factor: 1, unit: "ms" },
  { factor: 1e-3, unit: "s" },
] as const;

function timeAxisPrefix(stepMs: number): { factor: number; unit: string } {
  if (!Number.isFinite(stepMs) || stepMs <= 0) return TIME_PREFIXES[2];
  const stepScaled = stepMs * 1e3; // step in μs for comparison
  if (stepScaled < 0.1) return TIME_PREFIXES[0]; // ns
  if (stepScaled < 1) return TIME_PREFIXES[1];   // μs
  if (stepMs < 1) return TIME_PREFIXES[1];      // μs
  if (stepMs < 1e3) return TIME_PREFIXES[2];   // ms
  return TIME_PREFIXES[3];                       // s
}

function computeChannelStats(
  points: PlotPoint[],
): { amplitude: number; center: number; stdDev: number } {
  if (points.length === 0) {
    return { amplitude: 0, center: 0, stdDev: 0 };
  }
  const ys = points.map(getY);
  const min = Math.min(...ys);
  const max = Math.max(...ys);
  const center = ys.reduce((a, b) => a + b, 0) / ys.length;
  const variance =
    ys.reduce((acc, y) => acc + (y - center) ** 2, 0) / ys.length;
  const stdDev = Math.sqrt(variance);
  const amplitude = (max - min) / 2;
  return { amplitude, center, stdDev };
}

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

export const Plot = forwardRef<{ captureScale: () => void }, {
  channelVisibility: Record<ScopeChannel, boolean>;
  channelAttenuation: Record<ScopeChannel, Key>;
  mathState: MathState;
  channelVoltageScale: Record<ScopeChannel, { min: number; max: number }>;
  onChannelVoltageScaleChange: (channel: ScopeChannel, min: number, max: number) => void;
  onVoltageScaleFromFrames?: (config: Record<ScopeChannel, number>) => void;
  onStatsChange?: (stats: ChannelStats[]) => void;
  timeScale?: { min: number; max: number };
  onTimeScaleChange?: (min: number, max: number) => void;
  onTimeExtent?: (min: number, max: number) => void;
  triggerPlacingChannel?: ScopeChannel | null;
  onTriggerPlaced?: (channel: ScopeChannel, value: number) => void;
}>(function Plot(
  { channelVisibility, channelAttenuation, mathState, channelVoltageScale, onChannelVoltageScaleChange, onVoltageScaleFromFrames, onStatsChange, timeScale: timeScaleProp, onTimeExtent, triggerPlacingChannel = null, onTriggerPlaced },
  ref,
) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const echartsRef = useRef<ReactECharts>(null);
  const [frames, setFrames] = useState<Partial<Record<ScopeChannel, FrontendFrameData>>>({});
  const latestFramesRef = useRef<Partial<Record<ScopeChannel, FrontendFrameData>>>({});
  const channelVisibilityRef = useRef(channelVisibility);
  const frameTimesRef = useRef<number[]>([]);
  const [frameRate, setFrameRate] = useState(0);
  const suggestedChannelScalesRef = useRef<Record<ScopeChannel, { min: number; max: number }> | null>(null);
  const statsRef = useRef<ChannelStats[]>([]);
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

  // Resize ECharts when the container size changes (e.g. window resize)
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const resizeObserver = new ResizeObserver(() => {
      const chart = echartsRef.current?.getEchartsInstance?.();
      chart?.resize();
    });
    resizeObserver.observe(container);
    return () => resizeObserver.disconnect();
  }, []);

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
    if (!triggerPlacingChannel || !onTriggerPlaced) return;
    const chart = echartsRef.current?.getEchartsInstance?.();
    if (!chart) return;
    const scale = channelVoltageScale[triggerPlacingChannel];
    const { min, max } = scale;
    const zr = chart.getZr();
    const handler = (event: { offsetX: number; offsetY: number }) => {
      const pointInPixel = [event.offsetX, event.offsetY];
      const yAxisIndex = triggerPlacingChannel === "A" ? 0 : 1;
      const pointInGrid = chart.convertFromPixel(
        { gridIndex: 0, xAxisIndex: 0, yAxisIndex },
        pointInPixel,
      );
      if (Array.isArray(pointInGrid) && pointInGrid.length >= 2 && Number.isFinite(pointInGrid[1])) {
        const voltageY = pointInGrid[1];
        const range = max - min;
        const normalized = range !== 0 ? (voltageY - min) / range : 0.5;
        const value255 = Math.round(Math.max(0, Math.min(255, normalized * 255)));
        onTriggerPlaced(triggerPlacingChannel, value255);
      }
    };
    zr.on("click", handler);
    return () => {
      zr.off("click", handler);
    };
  }, [triggerPlacingChannel, onTriggerPlaced, channelVoltageScale]);

  useEffect(() => {
    let rafId: number;
    function tick() {
      rafId = requestAnimationFrame(tick);
      void commands.getCurrentFrame().then(([frameA, frameB]) => {
        const next = { A: frameA, B: frameB };
        latestFramesRef.current = next;
        setFrames(next);
        const now = performance.now();
        const times = frameTimesRef.current;
        times.push(now);
        const cutoff = now - 1000;
        while (times.length > 0 && times[0] < cutoff) {
          times.shift();
        }
        setFrameRate(times.length);
      });
    }
    rafId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafId);
  }, []);

  useEffect(() => {
    if (!onVoltageScaleFromFrames) return;
    const config: Record<ScopeChannel, number> = {
      A: frames.A?.voltage_scale ?? 1.5,
      B: frames.B?.voltage_scale ?? 1.5,
    };
    onVoltageScaleFromFrames(config);
  }, [frames.A?.voltage_scale, frames.B?.voltage_scale, onVoltageScaleFromFrames]);

  useEffect(() => {
    // Stats are computed in render and stored in statsRef; run when data or visibility changes
    void frames;
    void channelVisibility;
    void mathState;
    onStatsChange?.(statsRef.current);
  }, [frames, channelVisibility, mathState, onStatsChange]);

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

  // Suggested scales for Auto Scale: combined range for both channels, centered, min range = voltage_scale/20
  const suggestedChannelScales: Record<ScopeChannel, { min: number; max: number }> = {
    A: channelVoltageScale.A,
    B: channelVoltageScale.B,
  };
  if (allPoints.length > 0) {
    const combinedYMin = Math.min(...allPoints.map(getY));
    const combinedYMax = Math.max(...allPoints.map(getY));
    const center = (combinedYMin + combinedYMax) / 2;
    const dataSpan = combinedYMax - combinedYMin;
    const voltageScaleForMin = Math.max(
      frames.A?.voltage_scale ?? 1.5,
      frames.B?.voltage_scale ?? 1.5,
    );
    const minRange = voltageScaleForMin / 20;
    const range = Math.max(dataSpan, minRange);
    const halfRange = range / 2;
    const low = center - halfRange;
    const high = center + halfRange;
    const aligned =
      range > 0 ? alignDomainToGrid(low, high) : { domain: [center - 0.5, center + 0.5] as [number, number] };
    const shared = { min: aligned.domain[0], max: aligned.domain[1] };
    suggestedChannelScales.A = shared;
    suggestedChannelScales.B = shared;
  }
  suggestedChannelScalesRef.current = suggestedChannelScales;

  // Build stats for StatsBar (channels + math)
  const channelStatsList: ChannelStats[] = [];
  for (const { channel, points } of plotDataByChannel) {
    if (points.length === 0) continue;
    const { amplitude, center, stdDev } = computeChannelStats(points);
    channelStatsList.push({
      name: `Channel ${channel}`,
      color: chartTheme.series[channel],
      amplitude,
      center,
      stdDev,
    });
  }
  if (mathPoints && mathPoints.length > 0) {
    const { amplitude, center, stdDev } = computeChannelStats(mathPoints);
    channelStatsList.push({
      name: "Math",
      color: mathColor,
      amplitude,
      center,
      stdDev,
    });
  }
  statsRef.current = channelStatsList;

  const xDataExtent = allPoints.length > 0 ? (extent(allPoints, getX) as [number, number]) : null;

  let xDomain: [number, number] = defaultScale.xDomain;
  let yDomain: [number, number] = defaultScale.yDomain;
  let xStep = defaultScale.xStep;
  let yStep = defaultScale.yStep;

  if (xDataExtent) {
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
  }

  // Set initial channel scale once when we first receive data
  useEffect(() => {
    if (initialScaleSetRef.current) return;
    const hasData = Object.keys(frames).length > 0;
    if (hasData && suggestedChannelScalesRef.current) {
      const s = suggestedChannelScalesRef.current;
      onChannelVoltageScaleChange("A", s.A.min, s.A.max);
      onChannelVoltageScaleChange("B", s.B.min, s.B.max);
      initialScaleSetRef.current = true;
    }
  }, [frames, onChannelVoltageScaleChange]);

  useImperativeHandle(ref, () => ({
    captureScale() {
      if (suggestedChannelScalesRef.current) {
        const scales = suggestedChannelScalesRef.current;
        onChannelVoltageScaleChange("A", scales.A.min, scales.A.max);
        onChannelVoltageScaleChange("B", scales.B.min, scales.B.max);
      }
    },
  }), [onChannelVoltageScaleChange]);

  useEffect(() => {
    if (onTimeExtent && xDataExtent) {
      onTimeExtent(xDataExtent[0], xDataExtent[1]);
    }
  }, [onTimeExtent, xDataExtent?.[0], xDataExtent?.[1]]);

  const axisXDomain: [number, number] = timeScaleProp
    ? [timeScaleProp.min, timeScaleProp.max]
    : xDomain;
  const axisXStep = xStep;
  const timePrefix = timeAxisPrefix(axisXStep);

  const axisYStepA = alignDomainToGrid(
    channelVoltageScale.A.min,
    channelVoltageScale.A.max,
    8,
  ).step;
  const axisYStepB = alignDomainToGrid(
    channelVoltageScale.B.min,
    channelVoltageScale.B.max,
    8,
  ).step;

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
            ? Number((xRaw * timePrefix.factor).toPrecision(4))
            : xRaw;

        const lines = [
          `<div>t: ${x} ${timePrefix.unit}</div>`,
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
      name: timePrefix.unit,
      nameLocation: "end",
      nameGap: 8,
      nameTextStyle: {
        color: chartTheme.axisLabel,
      },
      axisLine: {
        lineStyle: {
          color: chartTheme.axisLine,
        },
      },
      axisLabel: {
        color: chartTheme.axisLabel,
        formatter: (value: number) => {
          if (!Number.isFinite(value)) return "";
          const scaled = value * timePrefix.factor;
          return Number(scaled.toPrecision(4)).toString();
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
              const scaled = value * timePrefix.factor;
              return Number(scaled.toPrecision(4)).toString();
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
    yAxis: [
      {
        type: "value",
        min: channelVoltageScale.A.min,
        max: channelVoltageScale.A.max,
        interval: axisYStepA,
        position: "left",
        axisLine: {
          lineStyle: { color: chartTheme.series.A },
        },
        axisLabel: {
          color: chartTheme.axisLabel,
          formatter: (value: number) =>
            Number.isFinite(value) ? Number(value.toPrecision(4)).toString() : "",
        },
        axisPointer: {
          lineStyle: { color: chartTheme.axisLine },
          label: {
            formatter: (params: { value: number | string }) =>
              typeof params.value === "number" && Number.isFinite(params.value)
                ? Number(params.value.toPrecision(4)).toString()
                : String(params.value ?? ""),
          },
        },
        splitLine: {
          show: true,
          lineStyle: { color: chartTheme.gridLine, width: 1 },
        },
      },
      {
        type: "value",
        min: channelVoltageScale.B.min,
        max: channelVoltageScale.B.max,
        interval: axisYStepB,
        position: "right",
        axisLine: {
          lineStyle: { color: chartTheme.series.B },
        },
        axisLabel: {
          color: chartTheme.axisLabel,
          formatter: (value: number) =>
            Number.isFinite(value) ? Number(value.toPrecision(4)).toString() : "",
        },
        axisPointer: {
          lineStyle: { color: chartTheme.axisLine },
          label: {
            formatter: (params: { value: number | string }) =>
              typeof params.value === "number" && Number.isFinite(params.value)
                ? Number(params.value.toPrecision(4)).toString()
                : String(params.value ?? ""),
          },
        },
        splitLine: { show: false },
      },
    ],
    series: [
      ...channelOrder.map((channel) => {
        const entry = plotDataByChannel.find((e) => e.channel === channel);
        const data = entry
          ? entry.points.map((point) => [point.x, point.y])
          : [];
        const yAxisIndex = channel === "A" ? 0 : 1;
        return {
          type: "line",
          name: `Channel ${channel}`,
          data,
          yAxisIndex,
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
        yAxisIndex: 0,
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
        ref={echartsRef}
        style={{ width: "100%", height: "100%" }}
        option={option}
        notMerge={false}
        lazyUpdate={true}
      />
    </div>
  );
});
