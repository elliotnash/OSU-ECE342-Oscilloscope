import { createFileRoute } from '@tanstack/react-router'
import { Channel } from '@tauri-apps/api/core'
import { useEffect, useState } from 'react'
import { commands, VerificationMessage, type FrameData } from '~/bindings'

export const Route = createFileRoute('/_subpage/test')({
  component: RouteComponent,
})

function RouteComponent() {
  const [frameData, setFrameData] = useState<FrameData|null>(null);
  const [verificationMessage, setVerificationMessage] = useState<VerificationMessage|null>(null);
  useEffect(() => {
    const onEvent = new Channel<FrameData>();
    onEvent.onmessage = (message) => {
      setFrameData(message);
    }
    commands.receiveFrames(onEvent);
  })
  useEffect(() => {
    const onEvent = new Channel<VerificationMessage>();
    onEvent.onmessage = (message) => {
      setVerificationMessage(message);
    }
    commands.receiveVerificationMessages(onEvent);
  })
  return <>
  <h1 className="text-xl">Frame Data</h1>
  <p>Center: {frameData?.center}</p>
  <p>Timestep: {frameData?.timestep_ms}</p>
  <p>Voltage Scale: {frameData?.voltage_scale}</p>
  <p>Channel: {frameData?.channel}</p>
  <p className="text-wrap">Data: {(frameData?.data ?? []).join(', ')}</p>
  <h1 className="text-xl">Verification Message</h1>
  <p>Message: {verificationMessage?.toString()}</p>
  </>
}
