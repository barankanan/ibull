import {
  RestaurantMutationInput,
  RestaurantMutationResult,
  RestaurantSnapshotResponse,
} from "@/features/restaurant/domain/commands";

export interface RestaurantRepository {
  getSnapshot(): Promise<RestaurantSnapshotResponse>;
  execute(mutation: RestaurantMutationInput): Promise<RestaurantMutationResult>;
}

export interface RestaurantClientAdapter {
  getSnapshot(): Promise<RestaurantSnapshotResponse>;
  execute(mutation: RestaurantMutationInput): Promise<RestaurantMutationResult>;
}
