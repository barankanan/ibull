import {
  RestaurantMutationInput,
  RestaurantMutationResult,
  RestaurantSnapshotResponse,
} from "@/features/restaurant/domain/commands";
import { RestaurantClientAdapter } from "@/features/restaurant/data/shared/repository";
import {
  executeRestaurantMutationAction,
  fetchRestaurantSnapshotAction,
} from "@/features/restaurant/server/actions";

/**
 * Browser-safe adapter: mutations and snapshots run through Next.js server
 * actions instead of public HTTP routes (no service-role exposure).
 */
export class ServerActionRestaurantClientAdapter
  implements RestaurantClientAdapter
{
  async getSnapshot(): Promise<RestaurantSnapshotResponse> {
    return fetchRestaurantSnapshotAction();
  }

  async execute(
    mutation: RestaurantMutationInput,
  ): Promise<RestaurantMutationResult> {
    return executeRestaurantMutationAction(mutation);
  }
}
