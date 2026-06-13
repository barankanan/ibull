import { NextRequest, NextResponse } from "next/server";
import { RestaurantRuntimeError } from "@/features/restaurant/domain/errors";
import { assertRestaurantApiAuthorized } from "@/features/restaurant/server/api-auth";
import { getRestaurantServerRepository } from "@/features/restaurant/server/repository";

export async function GET(request: NextRequest) {
  const authFailure = assertRestaurantApiAuthorized(request);
  if (authFailure) {
    return authFailure;
  }

  try {
    const repository = getRestaurantServerRepository();
    const snapshot = await repository.getSnapshot();
    return NextResponse.json(snapshot, { status: 200 });
  } catch (error) {
    const runtimeError =
      error instanceof RestaurantRuntimeError
        ? error
        : new RestaurantRuntimeError(
            "SNAPSHOT_ROUTE_FAILED",
            "Snapshot route failed.",
            {
              retriable: true,
              details: error,
            },
          );

    return NextResponse.json(
      {
        error: {
          code: runtimeError.code,
          message: runtimeError.message,
        },
      },
      { status: 500 },
    );
  }
}
