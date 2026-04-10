import { ApiRestaurantClientAdapter } from "@/features/restaurant/data/client/api-adapter";
import { LocalMockRestaurantClientAdapter } from "@/features/restaurant/data/client/mock-adapter";
import { RestaurantClientAdapter } from "@/features/restaurant/data/shared/repository";

export function createRestaurantClientAdapter(): RestaurantClientAdapter {
  const mode = process.env.NEXT_PUBLIC_RESTAURANT_CLIENT_ADAPTER ?? "api";
  if (mode === "mock-local") {
    return new LocalMockRestaurantClientAdapter();
  }
  return new ApiRestaurantClientAdapter();
}
