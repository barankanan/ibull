import { NextRequest, NextResponse } from "next/server";

function unauthorizedResponse() {
  return NextResponse.json(
    {
      error: {
        code: "UNAUTHORIZED",
        message: "Restaurant API access denied.",
      },
    },
    { status: 401 },
  );
}

function misconfiguredResponse() {
  return NextResponse.json(
    {
      error: {
        code: "API_NOT_CONFIGURED",
        message: "Restaurant API secret is not configured.",
      },
    },
    { status: 503 },
  );
}

/**
 * Guards HTTP API routes that use the Supabase service-role repository.
 * Mock mode stays open for local development; supabase mode requires
 * `x-restaurant-api-key` matching RESTAURANT_API_SECRET.
 */
export function assertRestaurantApiAuthorized(
  request: NextRequest,
): NextResponse | null {
  const dataSource = process.env.RESTAURANT_DATA_SOURCE ?? "mock";
  if (dataSource !== "supabase") {
    return null;
  }

  const secret = process.env.RESTAURANT_API_SECRET?.trim();
  if (!secret) {
    return misconfiguredResponse();
  }

  const provided = request.headers.get("x-restaurant-api-key")?.trim();
  if (!provided || provided !== secret) {
    return unauthorizedResponse();
  }

  return null;
}
