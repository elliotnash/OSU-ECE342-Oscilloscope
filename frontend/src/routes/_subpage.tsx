import { ArrowLeftIcon } from '@heroicons/react/24/solid'
import { createFileRoute, Outlet, useRouter } from '@tanstack/react-router'
import { Button } from '~/components/button'
import { Titlebar } from '~/components/titlebar'

export const Route = createFileRoute('/_subpage')({
  component: RouteComponent,
})

function RouteComponent() {

  const router = useRouter();

  return (
    <>
      <Titlebar menuButton={
        <Button size="sq-sm" intent="outline" onClick={() => router.history.back()}>
          <ArrowLeftIcon/>
        </Button>
      }/>
      <Outlet />
    </>
  )
}
