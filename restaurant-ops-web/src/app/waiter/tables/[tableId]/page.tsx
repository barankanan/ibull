import { WaiterRouteScreen } from "@/features/restaurant/app/WaiterRouteScreen";

export default async function WaiterTablePage({
  params,
}: {
  params: Promise<{ tableId: string }>;
}) {
  const { tableId } = await params;
  return <WaiterRouteScreen initialTableId={tableId} />;
}
