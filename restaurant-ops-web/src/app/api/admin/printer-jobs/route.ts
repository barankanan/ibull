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
    const tableId = request.nextUrl.searchParams.get("tableId");
    const repository = getRestaurantServerRepository();
    const snapshot = await repository.getSnapshot();
    const printerJobs = tableId
      ? snapshot.snapshot.printerJobs.filter((job) => job.tableId === tableId)
      : snapshot.snapshot.printerJobs;

    return NextResponse.json(
      {
        printerJobs,
      },
      { status: 200 },
    );
  } catch (error) {
    const runtimeError =
      error instanceof RestaurantRuntimeError
        ? error
        : new RestaurantRuntimeError(
            "PRINTER_JOBS_ROUTE_FAILED",
            "Printer jobs route failed.",
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
