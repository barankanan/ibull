import { ConflictPayload, RestaurantMutationResult } from "@/features/restaurant/domain/commands";
import { RestaurantStoreState } from "@/features/restaurant/domain/model";

export class RestaurantRuntimeError extends Error {
  code: string;
  retriable: boolean;
  snapshot?: RestaurantStoreState;
  details?: unknown;

  constructor(
    code: string,
    message: string,
    options?: {
      retriable?: boolean;
      snapshot?: RestaurantStoreState;
      details?: unknown;
    },
  ) {
    super(message);
    this.name = "RestaurantRuntimeError";
    this.code = code;
    this.retriable = options?.retriable ?? false;
    this.snapshot = options?.snapshot;
    this.details = options?.details;
  }
}

export function assertMutationResult(
  result: RestaurantMutationResult,
): RestaurantMutationResult {
  if (result.conflict) {
    throw fromConflict(result.conflict);
  }
  return result;
}

export function fromConflict(conflict: ConflictPayload) {
  return new RestaurantRuntimeError(conflict.code, conflict.message, {
    retriable: true,
    snapshot: conflict.latestSnapshot,
    details: conflict,
  });
}
