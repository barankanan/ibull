"use server";

import { RestaurantMutationInput } from "@/features/restaurant/domain/commands";
import { getRestaurantServerRepository } from "@/features/restaurant/server/repository";

export async function fetchRestaurantSnapshotAction() {
  const repository = getRestaurantServerRepository();
  return repository.getSnapshot();
}

export async function executeRestaurantMutationAction(
  mutation: RestaurantMutationInput,
) {
  const repository = getRestaurantServerRepository();
  return repository.execute(mutation);
}
