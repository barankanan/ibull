import { NextRequest, NextResponse } from "next/server";
import { RestaurantMutationInput } from "@/features/restaurant/domain/commands";
import { RestaurantRuntimeError } from "@/features/restaurant/domain/errors";
import { assertRestaurantApiAuthorized } from "@/features/restaurant/server/api-auth";
import { getRestaurantServerRepository } from "@/features/restaurant/server/repository";

function statusForError(error: RestaurantRuntimeError) {
  if (error.code === "TABLE_VERSION_CONFLICT") return 409;
  if (error.code.startsWith("UNSUPPORTED_")) return 501;
  if (
    error.code.includes("INVALID") ||
    error.code.includes("NOT_FOUND") ||
    error.code.includes("BLOCKS") ||
    error.code.includes("MISMATCH") ||
    error.code.includes("EMPTY") ||
    error.code.startsWith("TARGET_") ||
    error.code.startsWith("PAYMENT_") ||
    error.code.startsWith("SPLIT_")
  ) {
    return 422;
  }
  return 500;
}

export async function POST(request: NextRequest) {
  const authFailure = assertRestaurantApiAuthorized(request);
  if (authFailure) {
    return authFailure;
  }

  try {
    const body = (await request.json()) as { mutation?: RestaurantMutationInput };
    if (!body.mutation) {
      return NextResponse.json(
        {
          error: {
            code: "INVALID_REQUEST",
            message: "Mutation payload is required.",
          },
        },
        { status: 400 },
      );
    }

    const repository = getRestaurantServerRepository();
    const result = await repository.execute(body.mutation);
    return NextResponse.json(result, { status: 200 });
  } catch (error) {
    const runtimeError =
      error instanceof RestaurantRuntimeError
        ? error
        : new RestaurantRuntimeError(
            "COMMAND_ROUTE_FAILED",
            "Mutation route failed.",
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
        snapshot: runtimeError.snapshot,
      },
      {
        status: statusForError(runtimeError),
      },
    );
  }
}
