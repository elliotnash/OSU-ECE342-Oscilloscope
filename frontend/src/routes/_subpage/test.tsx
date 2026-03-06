import { createFileRoute } from '@tanstack/react-router'
import { Channel } from '@tauri-apps/api/core'
import { useEffect, useMemo, useState } from 'react'
import { commands, type VerificationMessage, type FrontendFrameData } from '~/bindings'
import { Button } from '~/components/button'

export const Route = createFileRoute('/_subpage/test')({
  component: RouteComponent,
})

function RouteComponent() {
  const [frameDataA, setFrameDataA] = useState<FrontendFrameData|null>(null);
  const [frameDataB, setFrameDataB] = useState<FrontendFrameData|null>(null);
  const [verificationMessage, setVerificationMessage] = useState<VerificationMessage|null>(null);
  useEffect(() => {
    const onEvent = new Channel<FrontendFrameData>();
    let frameCountA = 0;
    let frameCountB = 0;
    onEvent.onmessage = (message) => {
      if (message.channel === "A") {
        frameCountA++;
        if (frameCountA > 60) {
          setFrameDataA(message);
          frameCountA = 0;
        }
      } else if (message.channel === "B") {
        frameCountB++;
        if (frameCountB > 60) {
          setFrameDataB(message);
          frameCountB = 0;
        }
      }
    }
    commands.receiveFrames(onEvent);

    return () => {
      onEvent.onmessage = () => {};
    }
  }, [])
  useEffect(() => {
    const onEvent = new Channel<VerificationMessage>();
    onEvent.onmessage = (message) => {
      setVerificationMessage(message);
    }
    commands.receiveVerificationMessages(onEvent);

    return () => {
      onEvent.onmessage = () => {};
    }
  }, [])

  const avgA = useMemo(() => {
    if (!frameDataA) return 0;
    return Math.round(frameDataA.data.reduce((acc, curr) => acc + curr, 0) / frameDataA.data.length);
  }, [frameDataA]);
  const avgB = useMemo(() => {
    if (!frameDataB) return 0;
    return Math.round(frameDataB.data.reduce((acc, curr) => acc + curr, 0) / frameDataB.data.length);
  }, [frameDataB]);

  return <>
    <h1 className="text-xl">Calibration</h1>
    <Button className="m-4" onClick={() => commands.sendCalibrationMessage({CalibrateCenter: {channel: "A", value: avgA}})}>Calibrate Center CH A</Button>
    <Button className="m-4" onClick={() => commands.sendCalibrationMessage({CalibrateMax: {channel: "A", value: avgA}})}>Calibrate Max CH A</Button>
    <Button className="m-4" onClick={() => commands.sendCalibrationMessage({CalibrateMin: {channel: "A", value: avgA}})}>Calibrate Min CH A</Button> 
    <Button className="m-4" onClick={() => commands.sendCalibrationMessage({CalibrateCenter: {channel: "B", value: avgB}})}>Calibrate Center CH B</Button>
    <Button className="m-4" onClick={() => commands.sendCalibrationMessage({CalibrateMax: {channel: "B", value: avgB}})}>Calibrate Max CH B</Button>
    <Button className="m-4" onClick={() => commands.sendCalibrationMessage({CalibrateMin: {channel: "B", value: avgB}})}>Calibrate Min CH B</Button> 
    <h1 className="text-xl">Verification Message</h1>
    <p>Message: {verificationMessage?.toString()}</p>
    <Button className="m-4" onClick={() => commands.sendVerificationMessage("StartDacTest")}>Start DAC Test</Button>
    <Button className="m-4" onClick={() => commands.sendVerificationMessage("SetGpioHigh")}>Set GPIO High</Button>
    <Button className="m-4" onClick={() => commands.sendVerificationMessage("SetGpioLow")}>Set GPIO Low</Button>
    <h1 className="text-xl">Frame Data</h1>
    <p>Avg, CH A: {avgA}, CH B: {avgB}</p>
    <p>Center: {frameDataA?.center}</p>
    <p>Timestep: {frameDataA?.timestep_ms}</p>
    <p>Voltage Scale: {frameDataA?.voltage_scale}</p>
    <p>Channel: {frameDataA?.channel}</p>
    <p className="text-wrap">Data: {(frameDataA?.data ?? []).join(', ')}</p>
  </>
}
