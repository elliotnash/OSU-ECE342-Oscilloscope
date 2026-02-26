import { createFileRoute } from '@tanstack/react-router'
import { Channel } from '@tauri-apps/api/core'
import { useEffect, useState } from 'react'
import { commands, type VerificationMessage, type FrontendFrameData } from '~/bindings'
import { Button } from '~/components/button'

export const Route = createFileRoute('/_subpage/test')({
  component: RouteComponent,
})

function RouteComponent() {
  const [frameData, setFrameData] = useState<FrontendFrameData|null>(null);
  const [verificationMessage, setVerificationMessage] = useState<VerificationMessage|null>(null);
  useEffect(() => {
    const onEvent = new Channel<FrontendFrameData>();
    let frameCount = 0;
    onEvent.onmessage = (message) => {
      frameCount++;
      if (frameCount > 60) {
        setFrameData(message);
        frameCount = 0;
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
  return <>
  <h1 className="text-xl">Verification Message</h1>
  <p>Message: {verificationMessage?.toString()}</p>
  <Button className="m-4" onClick={() => commands.sendVerificationMessage("StartDacTest")}>Start DAC Test</Button>
  <Button className="m-4" onClick={() => commands.sendVerificationMessage("SetGpioHigh")}>Set GPIO High</Button>
  <Button className="m-4" onClick={() => commands.sendVerificationMessage("SetGpioLow")}>Set GPIO Low</Button>
  <h1 className="text-xl">Frame Data</h1>
  <p>Center: {frameData?.center}</p>
  <p>Timestep: {frameData?.timestep_ms}</p>
  <p>Voltage Scale: {frameData?.voltage_scale}</p>
  <p>Channel: {frameData?.channel}</p>
  <p className="text-wrap">Data: {(frameData?.data ?? []).join(', ')}</p>
  </>
}
