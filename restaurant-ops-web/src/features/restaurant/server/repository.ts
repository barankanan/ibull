import { MockRestaurantRepository } from "@/features/restaurant/data/mock/mock-repository";
import { RestaurantRepository } from "@/features/restaurant/data/shared/repository";
import { createSupabaseAdminClient } from "@/features/restaurant/data/supabase/client";
import { SupabaseRestaurantRepository } from "@/features/restaurant/data/supabase/supabase-repository";

let mockRepository: RestaurantRepository | null = null;

export function getRestaurantServerRepository(): RestaurantRepository {
  const mode = process.env.RESTAURANT_DATA_SOURCE ?? "mock";

  if (mode === "supabase") {
    return new SupabaseRestaurantRepository(createSupabaseAdminClient());
  }

  if (!mockRepository) {
    mockRepository = new MockRestaurantRepository();
  }

  return mockRepository;
}
