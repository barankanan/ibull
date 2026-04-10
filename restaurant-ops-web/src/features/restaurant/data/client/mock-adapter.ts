import {
  RestaurantMutationInput,
  RestaurantMutationResult,
  RestaurantSnapshotResponse,
} from "@/features/restaurant/domain/commands";
import { createInitialState } from "@/lib/mock-data";
import {
  applyRestaurantMutation,
  cloneRestaurantState,
  extractChangedTables,
} from "@/features/restaurant/domain/reducer";
import { validateRestaurantMutation } from "@/features/restaurant/data/shared/guards";
import { RestaurantClientAdapter } from "@/features/restaurant/data/shared/repository";

let clientSnapshot = createInitialState();

function simulateLatency() {
  return new Promise((resolve) => {
    window.setTimeout(resolve, 180);
  });
}

export class LocalMockRestaurantClientAdapter implements RestaurantClientAdapter {
  async getSnapshot(): Promise<RestaurantSnapshotResponse> {
    await simulateLatency();
    return {
      snapshot: cloneRestaurantState(clientSnapshot),
    };
  }

  async execute(
    mutation: RestaurantMutationInput,
  ): Promise<RestaurantMutationResult> {
    await simulateLatency();
    validateRestaurantMutation(clientSnapshot, mutation);
    clientSnapshot = applyRestaurantMutation(clientSnapshot, mutation);
    const changedTableIds = extractChangedTables(mutation);
    return {
      snapshot: cloneRestaurantState(clientSnapshot),
      appliedMutationId: mutation.clientMutationId,
      operationLogIds: clientSnapshot.tables
        .filter((table) => changedTableIds.includes(table.id))
        .flatMap((table) => table.logs.slice(0, 1).map((log) => log.id)),
      changedTableIds,
    };
  }
}
