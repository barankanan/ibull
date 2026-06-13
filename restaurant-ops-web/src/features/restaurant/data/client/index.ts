import { ApiRestaurantClientAdapter } from "@/features/restaurant/data/client/api-adapter";
import { LocalMockRestaurantClientAdapter } from "@/features/restaurant/data/client/mock-adapter";
import { ServerActionRestaurantClientAdapter } from "@/features/restaurant/data/client/server-action-adapter";
import { RestaurantClientAdapter } from "@/features/restaurant/data/shared/repository";

export function createRestaurantClientAdapter(): RestaurantClientAdapter {
  const mode = process.env.NEXT_PUBLIC_RESTAURANT_CLIENT_ADAPTER ?? "server-action";
  if (mode === "mock-local") {
    return new LocalMockRestaurantClientAdapter();
  }
  if (mode === "api") {
    return new ApiRestaurantClientAdapter();
  }
  return new ServerActionRestaurantClientAdapter();
}
