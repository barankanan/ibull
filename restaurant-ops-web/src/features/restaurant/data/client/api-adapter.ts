import {
  RestaurantMutationInput,
  RestaurantMutationResult,
  RestaurantSnapshotResponse,
} from "@/features/restaurant/domain/commands";
import { RestaurantRuntimeError, assertMutationResult } from "@/features/restaurant/domain/errors";
import { RestaurantClientAdapter } from "@/features/restaurant/data/shared/repository";

async function parseJsonSafe(response: Response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

export class ApiRestaurantClientAdapter implements RestaurantClientAdapter {
  async getSnapshot(): Promise<RestaurantSnapshotResponse> {
    const response = await fetch("/api/restaurant/snapshot", {
      method: "GET",
      cache: "no-store",
    });
    if (!response.ok) {
      const payload = await parseJsonSafe(response);
      throw new RestaurantRuntimeError(
        payload?.error?.code ?? "SNAPSHOT_FETCH_FAILED",
        payload?.error?.message ?? "Snapshot fetch failed.",
        {
          retriable: true,
          details: payload,
        },
      );
    }
    return response.json();
  }

  async execute(
    mutation: RestaurantMutationInput,
  ): Promise<RestaurantMutationResult> {
    const response = await fetch("/api/restaurant/commands", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ mutation }),
    });
    const payload = await parseJsonSafe(response);
    if (!response.ok) {
      throw new RestaurantRuntimeError(
        payload?.error?.code ?? "COMMAND_FAILED",
        payload?.error?.message ?? "Mutation execution failed.",
        {
          retriable: response.status >= 500 || response.status === 409,
          snapshot: payload?.snapshot,
          details: payload,
        },
      );
    }
    return assertMutationResult(payload as RestaurantMutationResult);
  }
}
