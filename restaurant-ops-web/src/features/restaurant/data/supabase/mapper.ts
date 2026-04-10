import { Database, Json } from "@/features/restaurant/domain/database.types";
import {
  BillSplitPart,
  BillSplitPlan,
  Customer,
  DraftState,
  OperationLog,
  OrderItem,
  PrinterJob,
  Product,
  ProductCategory,
  RestaurantStoreState,
  RestaurantTable,
  TableOrder,
} from "@/features/restaurant/domain/model";

type TablesSchema = Database["restaurant"]["Tables"];

function asRecord(value: Json | null | undefined) {
  if (!value || Array.isArray(value) || typeof value !== "object") {
    return {};
  }
  return value as Record<string, Json>;
}

function mapOrderItemFromRow(
  row:
    | TablesSchema["draft_items"]["Row"]
    | TablesSchema["check_items"]["Row"],
): OrderItem {
  const customizations = asRecord(row.customizations_payload);
  const service = row.service_payload ? asRecord(row.service_payload) : null;

  return {
    id: row.id,
    productId: row.product_id,
    name: row.name,
    kind: row.kind,
    quantity: row.quantity,
    unitPrice: row.unit_price,
    totalPrice: row.total_price,
    status: row.status,
    createdAt: row.created_at,
    version: row.revision,
    customizations: {
      note: String(customizations.note ?? ""),
      modifiers: Array.isArray(customizations.modifiers)
        ? (customizations.modifiers as string[])
        : [],
      grams:
        typeof customizations.grams === "number"
          ? customizations.grams
          : undefined,
    },
    service: service
      ? {
          serviceName: String(service.serviceName ?? ""),
          orderName: String(service.orderName ?? row.name),
          structure:
            (service.structure as
              | "standard"
              | "1_plate"
              | "2_plate"
              | "3_plate"
              | "4_plate"
              | "5_plate") ?? "standard",
          plateCount: Number(service.plateCount ?? 0),
          note: String(service.note ?? ""),
          items: Array.isArray(service.items)
            ? (service.items as unknown as NonNullable<OrderItem["service"]>["items"])
            : [],
        }
      : undefined,
  };
}

export function buildSnapshotFromSupabaseRows(input: {
  venueId: string;
  source: "supabase";
  categories: TablesSchema["product_categories"]["Row"][];
  products: TablesSchema["products"]["Row"][];
  customers: TablesSchema["customers"]["Row"][];
  tables: TablesSchema["tables"]["Row"][];
  drafts: TablesSchema["table_drafts"]["Row"][];
  draftItems: TablesSchema["draft_items"]["Row"][];
  checks: TablesSchema["checks"]["Row"][];
  checkItems: TablesSchema["check_items"]["Row"][];
  payments: TablesSchema["partial_payments"]["Row"][];
  splitPlans: TablesSchema["split_plans"]["Row"][];
  splitPlanParts: TablesSchema["split_plan_parts"]["Row"][];
  logs: TablesSchema["operation_logs"]["Row"][];
  printLogs: TablesSchema["print_logs"]["Row"][];
}): RestaurantStoreState {
  const categories: ProductCategory[] = input.categories.map((row) => ({
    id: row.id,
    name: row.name,
    description: row.description,
    sortOrder: row.sort_order,
  }));

  const products: Product[] = input.products.map((row) => ({
    id: row.id,
    sku: row.sku,
    name: row.name,
    categoryId: row.category_id,
    price: row.base_price,
    kind: row.kind,
    description: row.description,
    stockState: row.stock_state,
    stockLabel: row.stock_label,
    prepMinutes: row.prep_minutes,
    visualTone: row.visual_tone,
    quickWeightOptions: row.quick_weight_options ?? undefined,
    suggestionIds: row.suggestion_ids ?? undefined,
    tags: row.tags ?? undefined,
    isFavorite: row.is_favorite,
    isPopular: row.is_popular,
    version: row.revision,
  }));

  const customers: Customer[] = input.customers.map((row) => ({
    id: row.id,
    name: row.name,
    phone: row.phone,
    company: row.company ?? undefined,
    loyaltyTier: row.loyalty_tier,
    visitCount: row.visit_count,
    averageSpend: row.average_spend,
    favoriteProductIds: row.favorite_product_ids,
    notes: row.notes,
    lastVisitAt: row.last_visit_at ?? row.updated_at,
    version: row.revision,
  }));

  const draftItemsByDraftId = new Map<string, OrderItem[]>();
  input.draftItems.forEach((row) => {
    const current = draftItemsByDraftId.get(row.draft_id) ?? [];
    current.push(mapOrderItemFromRow(row));
    draftItemsByDraftId.set(row.draft_id, current);
  });

  const checkItemsByCheckId = new Map<string, OrderItem[]>();
  input.checkItems.forEach((row) => {
    const current = checkItemsByCheckId.get(row.check_id) ?? [];
    current.push(mapOrderItemFromRow(row));
    checkItemsByCheckId.set(row.check_id, current);
  });

  const splitPlanPartsByPlanId = new Map<string, BillSplitPart[]>();
  input.splitPlanParts.forEach((row) => {
    const current = splitPlanPartsByPlanId.get(row.split_plan_id) ?? [];
    current.push({
      id: row.id,
      label: row.label,
      amount: row.amount,
      lineItemIds: row.line_item_ids,
    });
    splitPlanPartsByPlanId.set(row.split_plan_id, current);
  });

  const logsByTableId = new Map<string, OperationLog[]>();
  input.logs.forEach((row) => {
    if (!row.table_id) return;
    const current = logsByTableId.get(row.table_id) ?? [];
    current.push({
      id: row.id,
      type: row.type,
      title: row.title,
      description: row.description,
      createdAt: row.created_at,
      severity: row.severity,
      status: row.status,
      tableId: row.table_id,
      operationKey: row.operation_key,
      actorName: row.actor_name,
    });
    logsByTableId.set(row.table_id, current);
  });

  const paymentsByTableId = new Map<string, RestaurantTable["payments"]>();
  input.payments.forEach((row) => {
    const current = paymentsByTableId.get(row.table_id) ?? [];
    current.push({
      id: row.id,
      amount: row.amount,
      method: row.method,
      createdAt: row.created_at,
      kind: row.kind,
      note: row.note ?? undefined,
      remainingAfterPayment: row.remaining_after_payment ?? undefined,
      version: row.revision,
    });
    paymentsByTableId.set(row.table_id, current);
  });

  const splitPlansByTableId = new Map<string, BillSplitPlan[]>();
  input.splitPlans.forEach((row) => {
    const current = splitPlansByTableId.get(row.table_id) ?? [];
    current.push({
      id: row.id,
      mode: row.mode,
      createdAt: row.created_at,
      note: row.note ?? undefined,
      version: row.revision,
      parts: splitPlanPartsByPlanId.get(row.id) ?? [],
    });
    splitPlansByTableId.set(row.table_id, current);
  });

  const checksByTableId = new Map<string, TableOrder[]>();
  input.checks.forEach((row) => {
    const current = checksByTableId.get(row.table_id) ?? [];
    current.push({
      id: row.id,
      label: row.label,
      status: row.status,
      note: row.note ?? undefined,
      source: row.source,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      totalPrice: row.total_amount,
      version: row.revision,
      items: checkItemsByCheckId.get(row.id) ?? [],
    });
    checksByTableId.set(row.table_id, current);
  });

  const printerJobs: PrinterJob[] = input.printLogs.map((row) => {
    const payload = asRecord(row.payload);
    const rawItems = Array.isArray(payload.items) ? payload.items : [];

    return {
      id: row.id,
      venueId: row.venue_id,
      tableId: row.table_id,
      tableName: row.table_name,
      orderId: row.check_id,
      orderReference: row.order_reference,
      printType: row.print_type,
      printerTarget: row.printer_target,
      status: row.status,
      requestedBy: row.requested_by,
      totalAmount: row.total_amount,
      source:
        payload.source === "auto_on_submit" ? "auto_on_submit" : "manual_action",
      createdAt: row.created_at,
      printedAt: row.printed_at,
      items: rawItems
        .map((entry, index) => {
          if (!entry || Array.isArray(entry) || typeof entry !== "object") {
            return null;
          }
          const line = entry as Record<string, Json>;
          return {
            id: String(line.id ?? `print-line-${row.id}-${index}`),
            name: String(line.name ?? "Kalem"),
            quantity: Number(line.quantity ?? 0),
            totalPrice: Number(line.totalPrice ?? 0),
          };
        })
        .filter((entry): entry is PrinterJob["items"][number] => !!entry),
    };
  });

  const draftsByTableId = new Map<string, DraftState>();
  input.drafts.forEach((row) => {
    draftsByTableId.set(row.table_id, {
      id: row.id,
      editingOrderId: row.editing_check_id,
      updatedAt: row.updated_at,
      version: row.revision,
      items: draftItemsByDraftId.get(row.id) ?? [],
    });
  });

  const tables: RestaurantTable[] = input.tables.map((row) => {
    const reservation = row.reservation_payload
      ? (row.reservation_payload as unknown as RestaurantTable["reservation"])
      : null;
    return {
      id: row.id,
      venueId: row.venue_id,
      activeSessionId: row.active_session_id,
      name: row.name,
      zone: row.zone,
      seats: row.seat_count,
      guestCount: row.guest_count,
      status: row.status,
      openedAt: row.opened_at,
      lastActionAt: row.last_action_at,
      customerId: row.current_customer_id,
      reservation,
      referenceCode: row.reference_code ?? undefined,
      barcode: row.barcode ?? undefined,
      timedBilling: {
        enabled: row.timed_billing_enabled,
        startedAt: row.timed_billing_started_at ?? row.opened_at,
        ratePerHour: row.timed_billing_rate_per_hour ?? 0,
      },
      draft: draftsByTableId.get(row.id) ?? {
        items: [],
        editingOrderId: null,
        updatedAt: row.updated_at,
        version: 0,
      },
      orders: checksByTableId.get(row.id) ?? [],
      payments: paymentsByTableId.get(row.id) ?? [],
      splitPlans: splitPlansByTableId.get(row.id) ?? [],
      logs: (logsByTableId.get(row.id) ?? []).sort((a, b) =>
        b.createdAt.localeCompare(a.createdAt),
      ),
      version: row.revision,
      updatedBy: row.updated_by,
    };
  });

  return {
    categories,
    products,
    customers,
    printerJobs,
    tables,
    meta: {
      venueId: input.venueId,
      source: input.source,
      fetchedAt: new Date().toISOString(),
      snapshotVersion: `snapshot-${Date.now()}`,
      conflictStrategy: "server-wins",
      optimisticEnabled: true,
    },
  };
}
