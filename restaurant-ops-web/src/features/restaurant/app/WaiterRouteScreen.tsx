import { RestaurantWaiterApp } from "@/components/RestaurantWaiterApp";
import { getRestaurantServerRepository } from "@/features/restaurant/server/repository";

export async function WaiterRouteScreen({
  initialTableId,
}: {
  initialTableId?: string;
}) {
  const repository = getRestaurantServerRepository();
  const snapshot = await repository.getSnapshot();

  return (
    <RestaurantWaiterApp
      initialState={snapshot.snapshot}
      initialTableId={initialTableId}
    />
  );
}
