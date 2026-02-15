import { createFileRoute } from '@tanstack/react-router'
import { Titlebar } from '~/components/titlebar'

export const Route = createFileRoute('/')({
  component: RouteComponent,
})

function RouteComponent() {
  return (
    <>
    <Titlebar />
    <div className="flex-1 min-h-0 overflow-auto flex flex-col items-center justify-center gap-6">
      <h1 className="text-4xl font-semibold text-fg">Waiting for connection...</h1>
    </div>
    </>
  )
}
