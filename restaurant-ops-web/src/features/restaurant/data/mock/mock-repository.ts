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
import { RestaurantRepository } from "@/features/restaurant/data/shared/repository";

let runtimeSnapshot = createInitialState();

export function resetMockRestaurantSnapshot() {
  runtimeSnapshot = createInitialState();
}

export class MockRestaurantRepository implements RestaurantRepository {
  async getSnapshot(): Promise<RestaurantSnapshotResponse> {
    return {
      snapshot: cloneRestaurantState(runtimeSnapshot),
    };
  }

  async execute(
    mutation: RestaurantMutationInput,
  ): Promise<RestaurantMutationResult> {
    validateRestaurantMutation(runtimeSnapshot, mutation);
    runtimeSnapshot = applyRestaurantMutation(runtimeSnapshot, mutation);
    const changedTableIds = extractChangedTables(mutation);
    const operationLogIds = runtimeSnapshot.tables
      .filter((table) => changedTableIds.includes(table.id))
      .flatMap((table) => table.logs.slice(0, 1).map((log) => log.id));

    return {
      snapshot: cloneRestaurantState(runtimeSnapshot),
      appliedMutationId: mutation.clientMutationId,
      operationLogIds,
      changedTableIds,
    };
  }
}
