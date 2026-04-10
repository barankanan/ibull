import {
  Customer,
  ItemCustomizations,
  OperationLog,
  OrderItem,
  OrderStatus,
  Product,
  PrinterJob,
  PrintType,
  RestaurantTable,
  ServiceChildItem,
  TableOrder,
  TableStatus,
  TransferMode,
} from "@/lib/types";
import { makeId, roundCurrency } from "@/lib/utils";

export const ORDER_TIMELINE: Array<{ id: OrderStatus; label: string }> = [
  { id: "draft", label: "Taslak" },
  { id: "kitchen_sent", label: "Mutfaga Iletildi" },
  { id: "preparing", label: "Hazirlaniyor" },
  { id: "ready", label: "Servise Hazir" },
  { id: "served", label: "Teslim Edildi" },
  { id: "payment_pending", label: "Odeme Bekliyor" },
  { id: "completed", label: "Tamamlandi" },
];

export const TABLE_STATUS_META: Record<
  TableStatus,
  { label: string; className: string }
> = {
  empty: {
    label: "Bos",
    className: "bg-white/80 text-slate-600 border border-slate-200",
  },
  active: {
    label: "Aktif",
    className: "bg-violet-100 text-violet-700 border border-violet-200",
  },
  kitchen_sent: {
    label: "Mutfaga Iletildi",
    className: "bg-indigo-100 text-indigo-700 border border-indigo-200",
  },
  preparing: {
    label: "Hazirlaniyor",
    className: "bg-amber-100 text-amber-700 border border-amber-200",
  },
  ready: {
    label: "Servise Hazir",
    className: "bg-cyan-100 text-cyan-700 border border-cyan-200",
  },
  served: {
    label: "Servis Edildi",
    className: "bg-emerald-100 text-emerald-700 border border-emerald-200",
  },
  payment_pending: {
    label: "Odeme Bekliyor",
    className: "bg-rose-100 text-rose-700 border border-rose-200",
  },
  completed: {
    label: "Tamamlandi",
    className: "bg-slate-900 text-white border border-slate-900",
  },
};

export const ORDER_STATUS_META: Record<
  OrderStatus,
  { label: string; className: string }
> = {
  draft: {
    label: "Taslak",
    className: "bg-slate-100 text-slate-700 border border-slate-200",
  },
  kitchen_sent: TABLE_STATUS_META.kitchen_sent,
  preparing: TABLE_STATUS_META.preparing,
  ready: TABLE_STATUS_META.ready,
  served: TABLE_STATUS_META.served,
  payment_pending: TABLE_STATUS_META.payment_pending,
  completed: TABLE_STATUS_META.completed,
};

export const PRODUCT_TONE_CLASS: Record<Product["visualTone"], string> = {
  plum: "from-violet-500 via-fuchsia-500 to-violet-700",
  rose: "from-rose-400 via-fuchsia-500 to-rose-600",
  blue: "from-sky-400 via-cyan-500 to-indigo-600",
  mint: "from-emerald-400 via-teal-500 to-cyan-600",
  amber: "from-amber-400 via-orange-400 to-rose-500",
};

export const STOCK_META = {
  in_stock: "text-emerald-700 bg-emerald-50 border border-emerald-200",
  low: "text-amber-700 bg-amber-50 border border-amber-200",
  out: "text-rose-700 bg-rose-50 border border-rose-200",
};

export function emptyCustomizations(
  overrides: Partial<ItemCustomizations> = {},
): ItemCustomizations {
  return {
    note: "",
    modifiers: [],
    ...overrides,
  };
}

export function cloneServiceChildItem(item: ServiceChildItem): ServiceChildItem {
  return {
    ...item,
    modifiers: [...item.modifiers],
  };
}

export function cloneOrderItem(item: OrderItem): OrderItem {
  return {
    ...item,
    customizations: {
      ...item.customizations,
      modifiers: [...item.customizations.modifiers],
    },
    service: item.service
      ? {
          ...item.service,
          items: item.service.items.map(cloneServiceChildItem),
        }
      : undefined,
  };
}

export function calculateServiceTotal(item: OrderItem) {
  if (!item.service) return 0;
  return roundCurrency(
    item.service.items.reduce((sum, child) => sum + child.totalPrice, 0),
  );
}

export function calculateOrderItemTotal(item: OrderItem) {
  if (item.kind === "service") {
    return calculateServiceTotal(item);
  }
  const baseUnit =
    item.kind === "weighted" && item.customizations.grams
      ? item.unitPrice * (item.customizations.grams / 1000)
      : item.unitPrice;
  return roundCurrency(baseUnit * item.quantity);
}

export function syncOrderItem(item: OrderItem) {
  return {
    ...cloneOrderItem(item),
    totalPrice: calculateOrderItemTotal(item),
  };
}

export function calculateOrderTotal(order: TableOrder) {
  return roundCurrency(
    order.items.reduce((sum, item) => sum + calculateOrderItemTotal(item), 0),
  );
}

export function calculateDraftTotal(table: RestaurantTable) {
  return roundCurrency(
    table.draft.items.reduce((sum, item) => sum + calculateOrderItemTotal(item), 0),
  );
}

export function calculatePaidTotal(table: RestaurantTable) {
  return roundCurrency(table.payments.reduce((sum, payment) => sum + payment.amount, 0));
}

export function calculateTimedCharge(table: RestaurantTable) {
  if (!table.timedBilling?.enabled) return 0;
  const elapsedHours =
    (Date.now() - new Date(table.timedBilling.startedAt).getTime()) /
    (1000 * 60 * 60);
  return roundCurrency(elapsedHours * table.timedBilling.ratePerHour);
}

export function calculateGrossTotal(table: RestaurantTable) {
  const ordersTotal = table.orders.reduce((sum, order) => sum + order.totalPrice, 0);
  return roundCurrency(ordersTotal + calculateDraftTotal(table) + calculateTimedCharge(table));
}

export function calculateRemainingTotal(table: RestaurantTable) {
  return Math.max(0, roundCurrency(calculateGrossTotal(table) - calculatePaidTotal(table)));
}

export function getActiveOrders(table: RestaurantTable) {
  return table.orders.filter((order) => order.status !== "completed");
}

export function deriveTableStatus(table: RestaurantTable): TableStatus {
  if (
    table.orders.length === 0 &&
    table.draft.items.length === 0 &&
    table.payments.length === 0
  ) {
    return "empty";
  }
  if (table.orders.length > 0 && table.orders.every((order) => order.status === "completed")) {
    return "completed";
  }
  const statuses = getActiveOrders(table).map((order) => order.status);
  if (statuses.includes("payment_pending")) return "payment_pending";
  if (statuses.includes("served")) return "served";
  if (statuses.includes("ready")) return "ready";
  if (statuses.includes("preparing")) return "preparing";
  if (statuses.includes("kitchen_sent")) return "kitchen_sent";
  if (table.draft.items.length > 0) return "active";
  return "active";
}

export function nextOrderStatus(status: OrderStatus): OrderStatus {
  const index = ORDER_TIMELINE.findIndex((step) => step.id === status);
  if (index === -1 || index === ORDER_TIMELINE.length - 1) {
    return status;
  }
  return ORDER_TIMELINE[index + 1].id;
}

export function buildProductOrderItem(
  product: Product,
  overrides: Partial<OrderItem> = {},
): OrderItem {
  const baseItem: OrderItem = {
    id: makeId("line"),
    productId: product.id,
    name: product.name,
    kind: product.kind,
    quantity: 1,
    unitPrice: product.price,
    totalPrice: product.price,
    status: "draft",
    createdAt: new Date().toISOString(),
    customizations: emptyCustomizations(),
  };
  const merged: OrderItem = {
    ...baseItem,
    ...overrides,
    id: overrides.id ?? baseItem.id,
    createdAt: overrides.createdAt ?? baseItem.createdAt,
    customizations: {
      ...emptyCustomizations(),
      ...overrides.customizations,
      modifiers: overrides.customizations?.modifiers ?? [],
    },
  };
  return syncOrderItem(merged);
}

export function itemSignature(item: OrderItem) {
  return JSON.stringify({
    productId: item.productId,
    kind: item.kind,
    grams: item.customizations.grams ?? null,
    note: item.customizations.note.trim(),
    modifiers: [...item.customizations.modifiers].sort(),
    service: item.service
      ? {
          name: item.service.orderName,
          note: item.service.note,
          structure: item.service.structure,
          items: item.service.items.map((child) => ({
            productId: child.productId,
            quantity: child.quantity,
            plateNumber: child.plateNumber,
            note: child.note,
            modifiers: [...child.modifiers].sort(),
          })),
        }
      : null,
  });
}

export function addLog(
  table: RestaurantTable,
  input: Omit<OperationLog, "id" | "createdAt">,
) {
  const nextLog: OperationLog = {
    id: makeId("log"),
    createdAt: new Date().toISOString(),
    ...input,
  };
  return {
    ...table,
    lastActionAt: nextLog.createdAt,
    logs: [nextLog, ...table.logs].slice(0, 20),
  };
}

export function buildPrinterJob(input: {
  venueId?: string;
  table: RestaurantTable;
  order: TableOrder;
  printType: PrintType;
  requestedBy?: string | null;
  printerTarget?: string | null;
  source: "auto_on_submit" | "manual_action";
}) {
  const { table, order } = input;
  const nextJob: PrinterJob = {
    id: makeId("print"),
    venueId: input.venueId ?? table.venueId,
    tableId: table.id,
    tableName: table.name,
    orderId: order.id,
    orderReference: order.label,
    printType: input.printType,
    printerTarget:
      input.printerTarget ??
      (input.printType === "adisyon" ? "Kasa Adisyon Yazicisi" : "Mutfak Yazicisi"),
    status: "pending",
    items: order.items.map((item) => ({
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      totalPrice: calculateOrderItemTotal(item),
    })),
    totalAmount: calculateOrderTotal(order),
    requestedBy: input.requestedBy ?? "Restaurant Ops",
    source: input.source,
    createdAt: new Date().toISOString(),
    printedAt: null,
  };

  return nextJob;
}

export function findCustomerById(customers: Customer[], customerId?: string | null) {
  return customers.find((customer) => customer.id === customerId) ?? null;
}

export function getTopSuggestions(table: RestaurantTable, products: Product[], customer: Customer | null) {
  const preferredIds = customer?.favoriteProductIds ?? [];
  const fallbackCategoryIds = new Set(
    table.orders.flatMap((order) => order.items.map((item) => item.productId)),
  );
  return products
    .filter((product) => preferredIds.includes(product.id) || product.isPopular)
    .filter((product) => !fallbackCategoryIds.has(product.id))
    .slice(0, 4);
}

export function applyTransferModeLabel(mode: TransferMode) {
  switch (mode) {
    case "all":
      return "Tamamen aktar";
    case "merge":
      return "Siparisleri birlestir";
    case "draft-only":
      return "Sadece taslagi aktar";
    default:
      return mode;
  }
}
