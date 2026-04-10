import { NextResponse } from "next/server";
import { RestaurantRuntimeError } from "@/features/restaurant/domain/errors";
import { getRestaurantServerRepository } from "@/features/restaurant/server/repository";

export async function GET() {
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
