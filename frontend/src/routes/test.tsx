import { createFileRoute } from '@tanstack/react-router'
import { Channel } from '@tauri-apps/api/core'
import { useEffect, useState } from 'react'
import { commands, FrameData } from '~/bindings'

export const Route = createFileRoute('/test')({
  component: RouteComponent,
})

function RouteComponent() {
  const [data, setData] = useState<string>('');
  useEffect(() => {
    const onEvent = new Channel<FrameData>();
    onEvent.onmessage = (message) => {
      setData(JSON.stringify(message));
    }
    commands.receiveFrames(onEvent);
  })
  return <div>Frame data: {data}</div>
}
