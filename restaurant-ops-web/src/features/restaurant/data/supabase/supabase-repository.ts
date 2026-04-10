import { SupabaseClient } from "@supabase/supabase-js";
import {
  RestaurantMutationInput,
  RestaurantMutationResult,
  RestaurantSnapshotResponse,
} from "@/features/restaurant/domain/commands";
import { Database } from "@/features/restaurant/domain/database.types";
import { RestaurantRuntimeError } from "@/features/restaurant/domain/errors";
import { RestaurantRepository } from "@/features/restaurant/data/shared/repository";
import { buildSnapshotFromSupabaseRows } from "@/features/restaurant/data/supabase/mapper";

const defaultVenueId = process.env.RESTAURANT_VENUE_ID ?? "venue-demo";

export class SupabaseRestaurantRepository implements RestaurantRepository {
  constructor(private readonly client: SupabaseClient<Database>) {}

  private restaurant() {
    return this.client.schema("restaurant");
  }

  async getSnapshot(): Promise<RestaurantSnapshotResponse> {
    const restaurant = this.restaurant();

    const [
      categoriesResult,
      productsResult,
      customersResult,
      tablesResult,
      draftsResult,
      draftItemsResult,
      checksResult,
      checkItemsResult,
      paymentsResult,
      splitPlansResult,
      splitPlanPartsResult,
      logsResult,
      printLogsResult,
    ] = await Promise.all([
      restaurant.from("product_categories").select("*").eq("venue_id", defaultVenueId).order("sort_order"),
      restaurant.from("products").select("*").eq("venue_id", defaultVenueId).order("name"),
      restaurant.from("customers").select("*").eq("venue_id", defaultVenueId).order("name"),
      restaurant.from("tables").select("*").eq("venue_id", defaultVenueId).order("name"),
      restaurant.from("table_drafts").select("*"),
      restaurant.from("draft_items").select("*"),
      restaurant.from("checks").select("*").order("created_at", { ascending: false }),
      restaurant.from("check_items").select("*"),
      restaurant.from("partial_payments").select("*").order("created_at", { ascending: false }),
      restaurant.from("split_plans").select("*").order("created_at", { ascending: false }),
      restaurant.from("split_plan_parts").select("*"),
      restaurant.from("operation_logs").select("*").eq("venue_id", defaultVenueId).order("created_at", { ascending: false }).limit(300),
      restaurant.from("print_logs").select("*").eq("venue_id", defaultVenueId).order("created_at", { ascending: false }).limit(300),
    ]);

    const errors = [
      categoriesResult.error,
      productsResult.error,
      customersResult.error,
      tablesResult.error,
      draftsResult.error,
      draftItemsResult.error,
      checksResult.error,
      checkItemsResult.error,
      paymentsResult.error,
      splitPlansResult.error,
      splitPlanPartsResult.error,
      logsResult.error,
      printLogsResult.error,
    ].filter(Boolean);

    if (errors.length > 0) {
      throw new RestaurantRuntimeError(
        "SUPABASE_SNAPSHOT_FAILED",
        errors[0]?.message ?? "Supabase snapshot query failed.",
        {
          retriable: true,
          details: errors,
        },
      );
    }

    return {
      snapshot: buildSnapshotFromSupabaseRows({
        venueId: defaultVenueId,
        source: "supabase",
        categories: categoriesResult.data ?? [],
        products: productsResult.data ?? [],
        customers: customersResult.data ?? [],
        tables: tablesResult.data ?? [],
        drafts: draftsResult.data ?? [],
        draftItems: draftItemsResult.data ?? [],
        checks: checksResult.data ?? [],
        checkItems: checkItemsResult.data ?? [],
        payments: paymentsResult.data ?? [],
        splitPlans: splitPlansResult.data ?? [],
        splitPlanParts: splitPlanPartsResult.data ?? [],
        logs: logsResult.data ?? [],
        printLogs: printLogsResult.data ?? [],
      }),
    };
  }

  private async callRpc(functionName: string, args: Record<string, unknown>) {
    const { data, error } = await this.restaurant().rpc(functionName, args);
    if (error) {
      throw new RestaurantRuntimeError(
        "SUPABASE_RPC_FAILED",
        error.message,
        {
          retriable: true,
          details: {
            functionName,
            args,
            error,
          },
        },
      );
    }
    return (data ?? {}) as Record<string, unknown>;
  }

  private actorName(mutation: RestaurantMutationInput) {
    return mutation.actor?.name ?? "Restaurant Ops";
  }

  private extractOperationLogIds(response: Record<string, unknown>) {
    return Array.isArray(response.operation_log_ids)
      ? (response.operation_log_ids as string[])
      : [];
  }

  private async throwTableConflict(
    tableId: string,
    expectedRevision: number | undefined,
  ): Promise<never> {
    const latestSnapshot = await this.getSnapshot().catch(() => null);
    const latestTable = latestSnapshot?.snapshot.tables.find((table) => table.id === tableId);
    throw new RestaurantRuntimeError(
      "TABLE_VERSION_CONFLICT",
      "Masa baska bir kullanici tarafindan guncellenmis.",
      {
        retriable: true,
        snapshot: latestSnapshot?.snapshot,
        details: {
          tableId,
          expectedRevision,
          latestRevision: latestTable?.version ?? null,
        },
      },
    );
  }

  private async updateTableMetadata(
    mutation: Extract<
      RestaurantMutationInput,
      | { type: "SET_GUEST_COUNT" }
      | { type: "SET_REFERENCE_CODE" }
      | { type: "SET_BARCODE" }
      | { type: "SET_TIMED_BILLING" }
      | { type: "ADD_LOG" }
    >,
  ) {
    const expectedRevision = mutation.expectedTableVersion ?? 0;
    const updatePayload =
      mutation.type === "SET_GUEST_COUNT"
        ? {
            guest_count: mutation.guestCount,
          }
        : mutation.type === "SET_REFERENCE_CODE"
          ? {
              reference_code: mutation.code,
            }
          : mutation.type === "SET_BARCODE"
            ? {
                barcode: mutation.code,
              }
            : mutation.type === "SET_TIMED_BILLING"
              ? {
                  timed_billing_enabled: mutation.timedBilling.enabled,
                  timed_billing_started_at: mutation.timedBilling.startedAt,
                  timed_billing_rate_per_hour: mutation.timedBilling.ratePerHour,
                }
              : {};

    const { data, error } = await this.restaurant()
      .from("tables")
      .update({
        ...updatePayload,
        last_action_at: mutation.createdAt,
        updated_by: mutation.actor?.name ?? null,
        updated_at: mutation.createdAt,
        revision: expectedRevision + 1,
      })
      .eq("id", mutation.tableId)
      .eq("revision", expectedRevision)
      .select("id, revision")
      .maybeSingle();

    if (error) {
      throw new RestaurantRuntimeError("SUPABASE_UPDATE_FAILED", error.message, {
        retriable: true,
        details: error,
      });
    }

    if (!data) {
      await this.throwTableConflict(mutation.tableId, expectedRevision);
    }

    const { data: logRows, error: logError } = await this.restaurant()
      .from("operation_logs")
      .insert({
        venue_id: defaultVenueId,
        table_id: mutation.tableId,
        operation_key:
          mutation.type === "ADD_LOG"
            ? mutation.typeKey
            : mutation.type.toLowerCase(),
        type:
          mutation.type === "ADD_LOG"
            ? mutation.typeKey
            : mutation.type.toLowerCase(),
        title:
          mutation.type === "ADD_LOG"
            ? mutation.title
            : "Metadata guncellendi",
        description:
          mutation.type === "ADD_LOG"
            ? mutation.description
            : `${mutation.type} komutu uygulandi.`,
        status: "committed",
        severity: "info",
        actor_name: this.actorName(mutation),
        client_mutation_id: mutation.clientMutationId,
        payload: mutation,
      })
      .select("id");

    if (logError) {
      throw new RestaurantRuntimeError("SUPABASE_LOG_FAILED", logError.message, {
        retriable: true,
        details: logError,
      });
    }

    return (logRows ?? []).map((row) => row.id);
  }

  async execute(
    mutation: RestaurantMutationInput,
  ): Promise<RestaurantMutationResult> {
    let operationLogIds: string[] = [];
    let changedTableIds: string[] = [];

    switch (mutation.type) {
      case "SEND_DRAFT": {
        const response = await this.callRpc("upsert_check_from_draft", {
          p_table_id: mutation.tableId,
          p_expected_revision: mutation.expectedTableVersion ?? 0,
          p_editing_check_id: mutation.draft?.editingOrderId ?? null,
          p_items: mutation.draft?.items ?? [],
          p_client_mutation_id: mutation.clientMutationId,
          p_actor_name: this.actorName(mutation),
        });
        operationLogIds = this.extractOperationLogIds(response);
        changedTableIds = [mutation.tableId];
        break;
      }
      case "ADVANCE_ORDER_STATUS": {
        const response = await this.callRpc("advance_check_status", {
          p_table_id: mutation.tableId,
          p_check_id: mutation.orderId,
          p_expected_revision: mutation.expectedTableVersion ?? 0,
          p_client_mutation_id: mutation.clientMutationId,
          p_actor_name: this.actorName(mutation),
        });
        operationLogIds = this.extractOperationLogIds(response);
        changedTableIds = [mutation.tableId];
        break;
      }
      case "ADD_PARTIAL_PAYMENT":
      case "CLOSE_BILL": {
        const response = await this.callRpc("take_partial_payment", {
          p_table_id: mutation.tableId,
          p_expected_revision: mutation.expectedTableVersion ?? 0,
          p_amount: mutation.amount,
          p_method: mutation.method,
          p_kind:
            mutation.type === "CLOSE_BILL"
              ? "closing"
              : mutation.kind ?? "partial",
          p_note: mutation.note ?? null,
          p_client_mutation_id: mutation.clientMutationId,
          p_actor_name: this.actorName(mutation),
        });
        operationLogIds = this.extractOperationLogIds(response);
        changedTableIds = [mutation.tableId];
        break;
      }
      case "TRANSFER_TABLE": {
        const response = await this.callRpc("transfer_table", {
          p_source_table_id: mutation.sourceTableId,
          p_target_table_id: mutation.targetTableId,
          p_expected_source_revision: mutation.expectedTableVersion ?? 0,
          p_expected_target_revision: mutation.expectedTargetTableVersion ?? 0,
          p_mode: mutation.mode,
          p_client_mutation_id: mutation.clientMutationId,
          p_actor_name: this.actorName(mutation),
        });
        operationLogIds = this.extractOperationLogIds(response);
        changedTableIds = [mutation.sourceTableId, mutation.targetTableId];
        break;
      }
      case "CREATE_SPLIT_PLAN": {
        const response = await this.callRpc("create_split_plan", {
          p_table_id: mutation.tableId,
          p_expected_revision: mutation.expectedTableVersion ?? 0,
          p_mode: mutation.plan.mode,
          p_parts: mutation.plan.parts,
          p_note: mutation.plan.note ?? null,
          p_client_mutation_id: mutation.clientMutationId,
          p_actor_name: this.actorName(mutation),
        });
        operationLogIds = this.extractOperationLogIds(response);
        changedTableIds = [mutation.tableId];
        break;
      }
      case "ASSIGN_CUSTOMER": {
        const response = await this.callRpc("assign_customer", {
          p_table_id: mutation.tableId,
          p_expected_revision: mutation.expectedTableVersion ?? 0,
          p_customer_id: mutation.customerId,
          p_client_mutation_id: mutation.clientMutationId,
          p_actor_name: this.actorName(mutation),
        });
        operationLogIds = this.extractOperationLogIds(response);
        changedTableIds = [mutation.tableId];
        break;
      }
      case "CREATE_CUSTOMER_AND_ASSIGN": {
        const response = await this.callRpc("create_customer_and_assign", {
          p_table_id: mutation.tableId,
          p_expected_revision: mutation.expectedTableVersion ?? 0,
          p_customer_payload: mutation.customer,
          p_client_mutation_id: mutation.clientMutationId,
          p_actor_name: this.actorName(mutation),
        });
        operationLogIds = this.extractOperationLogIds(response);
        changedTableIds = [mutation.tableId];
        break;
      }
      case "REGISTER_PRINT": {
        const response = await this.callRpc("register_print_log", {
          p_table_id: mutation.tableId,
          p_expected_revision: mutation.expectedTableVersion ?? 0,
          p_print_type: mutation.printType.toLowerCase().includes("mutf")
            ? "mutfak"
            : "adisyon",
          p_client_mutation_id: mutation.clientMutationId,
          p_actor_name: this.actorName(mutation),
        });
        operationLogIds = this.extractOperationLogIds(response);
        changedTableIds = [mutation.tableId];
        break;
      }
      case "NEW_BILL": {
        const response = await this.callRpc("reset_table_for_new_bill", {
          p_table_id: mutation.tableId,
          p_expected_revision: mutation.expectedTableVersion ?? 0,
          p_client_mutation_id: mutation.clientMutationId,
          p_actor_name: this.actorName(mutation),
        });
        operationLogIds = this.extractOperationLogIds(response);
        changedTableIds = [mutation.tableId];
        break;
      }
      case "UPDATE_ORDER_ITEM": {
        const response = await this.callRpc("update_check_item", {
          p_table_id: mutation.tableId,
          p_check_id: mutation.orderId,
          p_item_id: mutation.itemId,
          p_expected_revision: mutation.expectedTableVersion ?? 0,
          p_updates: mutation.updates,
          p_client_mutation_id: mutation.clientMutationId,
          p_actor_name: this.actorName(mutation),
        });
        operationLogIds = this.extractOperationLogIds(response);
        changedTableIds = [mutation.tableId];
        break;
      }
      case "REMOVE_ORDER_ITEM": {
        const response = await this.callRpc("remove_check_item", {
          p_table_id: mutation.tableId,
          p_check_id: mutation.orderId,
          p_item_id: mutation.itemId,
          p_expected_revision: mutation.expectedTableVersion ?? 0,
          p_client_mutation_id: mutation.clientMutationId,
          p_actor_name: this.actorName(mutation),
        });
        operationLogIds = this.extractOperationLogIds(response);
        changedTableIds = [mutation.tableId];
        break;
      }
      case "MOVE_ORDER_ITEMS": {
        const response = await this.callRpc("move_check_items", {
          p_source_table_id: mutation.sourceTableId,
          p_target_table_id: mutation.targetTableId,
          p_item_ids: mutation.itemIds,
          p_expected_source_revision: mutation.expectedTableVersion ?? 0,
          p_expected_target_revision: mutation.expectedTargetTableVersion ?? 0,
          p_client_mutation_id: mutation.clientMutationId,
          p_actor_name: this.actorName(mutation),
        });
        operationLogIds = this.extractOperationLogIds(response);
        changedTableIds = [mutation.sourceTableId, mutation.targetTableId];
        break;
      }
      case "SET_GUEST_COUNT":
      case "SET_REFERENCE_CODE":
      case "SET_BARCODE":
      case "SET_TIMED_BILLING":
      case "ADD_LOG": {
        operationLogIds = await this.updateTableMetadata(mutation);
        changedTableIds = [mutation.tableId];
        break;
      }
      default:
        throw new RestaurantRuntimeError(
          "UNSUPPORTED_REMOTE_MUTATION",
          `${mutation.type} is not yet wired to the Supabase repository. Keep it as UI-local or add an RPC handler.`,
        );
    }

    const snapshot = await this.getSnapshot();
    return {
      snapshot: snapshot.snapshot,
      appliedMutationId: mutation.clientMutationId,
      operationLogIds,
      changedTableIds,
    };
  }
}
