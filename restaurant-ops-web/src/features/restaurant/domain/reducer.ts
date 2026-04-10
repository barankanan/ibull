import {
  RestaurantMutationInput,
} from "@/features/restaurant/domain/commands";
import {
  BillSplitPlan,
  Customer,
  OrderItem,
  RestaurantStoreState,
  RestaurantTable,
  TableOrder,
} from "@/features/restaurant/domain/model";
import {
  addLog,
  buildPrinterJob,
  applyTransferModeLabel,
  calculateOrderItemTotal,
  calculateOrderTotal,
  cloneOrderItem,
  deriveTableStatus,
  itemSignature,
  nextOrderStatus,
} from "@/lib/restaurant";
import { makeId } from "@/lib/utils";

function mergeIntoDraft(items: OrderItem[], incoming: OrderItem) {
  if (incoming.kind === "service") {
    return [...items, cloneOrderItem(incoming)];
  }
  const signature = itemSignature(incoming);
  const existing = items.find((item) => itemSignature(item) === signature);
  if (!existing) {
    return [...items, cloneOrderItem(incoming)];
  }
  return items.map((item) =>
    item.id === existing.id
      ? {
          ...item,
          quantity: item.quantity + incoming.quantity,
          totalPrice: calculateOrderItemTotal({
            ...item,
            quantity: item.quantity + incoming.quantity,
          }),
        }
      : item,
  );
}

function finalizeState(state: RestaurantStoreState, changedTableIds: string[]) {
  const changedSet = new Set(changedTableIds);
  const now = new Date().toISOString();

  return {
    ...state,
    tables: state.tables.map((table) => {
      if (!changedSet.has(table.id)) {
        return {
          ...table,
          status: deriveTableStatus(table),
        };
      }
      return {
        ...table,
        version: (table.version ?? 0) + 1,
        lastActionAt: table.lastActionAt || now,
        status: deriveTableStatus(table),
      };
    }),
    meta: {
      ...state.meta,
      fetchedAt: now,
      snapshotVersion: makeId("snapshot"),
    },
  };
}

export function cloneRestaurantState(state: RestaurantStoreState): RestaurantStoreState {
  return structuredClone(state);
}

export function applyRestaurantMutation(
  state: RestaurantStoreState,
  action: RestaurantMutationInput,
): RestaurantStoreState {
  switch (action.type) {
    case "ADD_DRAFT_ITEM":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) => {
            if (table.id !== action.tableId) return table;
            return addLog(
              {
                ...table,
                draft: {
                  ...table.draft,
                  items: mergeIntoDraft(table.draft.items, action.item),
                  updatedAt: action.createdAt,
                },
              },
              {
                type: "draft_add",
                title: "Taslaga eklendi",
                description: `${action.item.name} taslaga eklendi.`,
                severity: "success",
              },
            );
          }),
        },
        [action.tableId],
      );
    case "UPDATE_DRAFT_ITEM":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) => {
            if (table.id !== action.tableId) return table;
            return {
              ...table,
              draft: {
                ...table.draft,
                updatedAt: action.createdAt,
                items: table.draft.items.map((item) =>
                  item.id === action.itemId
                    ? {
                        ...item,
                        ...action.updates,
                        customizations: {
                          ...item.customizations,
                          ...action.updates.customizations,
                          modifiers:
                            action.updates.customizations?.modifiers ??
                            item.customizations.modifiers,
                        },
                        totalPrice: calculateOrderItemTotal({
                          ...item,
                          ...action.updates,
                          customizations: {
                            ...item.customizations,
                            ...action.updates.customizations,
                            modifiers:
                              action.updates.customizations?.modifiers ??
                              item.customizations.modifiers,
                          },
                        }),
                      }
                    : item,
                ),
              },
            };
          }),
        },
        [action.tableId],
      );
    case "REMOVE_DRAFT_ITEM":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) => {
            if (table.id !== action.tableId) return table;
            return addLog(
              {
                ...table,
                draft: {
                  ...table.draft,
                  items: table.draft.items.filter((item) => item.id !== action.itemId),
                  updatedAt: action.createdAt,
                },
              },
              {
                type: "draft_remove",
                title: "Taslak urun silindi",
                description: "Secili taslak satiri kaldirildi.",
                severity: "warning",
              },
            );
          }),
        },
        [action.tableId],
      );
    case "CLEAR_DRAFT":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) => {
            if (table.id !== action.tableId) return table;
            return addLog(
              {
                ...table,
                draft: {
                  items: [],
                  editingOrderId: null,
                  updatedAt: action.createdAt,
                },
              },
              {
                type: "draft_clear",
                title: "Taslak temizlendi",
                description: "Yeni siparis taslagi sifirlandi.",
                severity: "warning",
              },
            );
          }),
        },
        [action.tableId],
      );
    case "LOAD_ORDER_INTO_DRAFT":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) => {
            if (table.id !== action.tableId) return table;
            const selectedOrder = table.orders.find((order) => order.id === action.orderId);
            if (!selectedOrder) return table;
            return addLog(
              {
                ...table,
                draft: {
                  items: selectedOrder.items.map(cloneOrderItem).map((item) => ({
                    ...item,
                    status: "draft",
                  })),
                  editingOrderId: selectedOrder.id,
                  updatedAt: action.createdAt,
                },
              },
              {
                type: "draft_edit",
                title: "Siparis taslaga alindi",
                description: `${selectedOrder.label} guncelleme icin taslaga alindi.`,
                severity: "info",
              },
            );
          }),
        },
        [action.tableId],
      );
    case "SEND_DRAFT":
      {
        let submittedOrder: TableOrder | null = null;
        let submittedTable: RestaurantTable | null = null;

        const nextState = finalizeState(
          {
            ...state,
            tables: state.tables.map((table) => {
              if (table.id !== action.tableId) return table;
              const activeDraft = action.draft ?? table.draft;
              if (activeDraft.items.length === 0) return table;
              const draftItems = activeDraft.items.map((item) => ({
                ...cloneOrderItem(item),
                status: "kitchen_sent" as const,
              }));
              const updatedOrders = [...table.orders];
              if (activeDraft.editingOrderId) {
                const index = updatedOrders.findIndex(
                  (order) => order.id === activeDraft.editingOrderId,
                );
                if (index >= 0) {
                  const current = updatedOrders[index];
                  const nextOrder: TableOrder = {
                    ...current,
                    status: "kitchen_sent",
                    items: draftItems,
                    updatedAt: action.createdAt,
                    totalPrice: calculateOrderTotal({
                      ...current,
                      items: draftItems,
                    }),
                  };
                  updatedOrders[index] = nextOrder;
                  submittedOrder = nextOrder;
                }
              } else {
                const nextOrder: TableOrder = {
                  id: makeId("order"),
                  label: `Yeni Fis ${updatedOrders.length + 1}`,
                  status: "kitchen_sent",
                  items: draftItems,
                  totalPrice: draftItems.reduce(
                    (sum, item) => sum + calculateOrderItemTotal(item),
                    0,
                  ),
                  createdAt: action.createdAt,
                  updatedAt: action.createdAt,
                  source: "waiter",
                  version: 1,
                };
                updatedOrders.unshift(nextOrder);
                submittedOrder = nextOrder;
              }

              const nextTable = addLog(
                {
                  ...table,
                  orders: updatedOrders,
                  draft: {
                    items: [],
                    editingOrderId: null,
                    updatedAt: action.createdAt,
                  },
                },
                {
                  type: "draft_send",
                  title: activeDraft.editingOrderId
                    ? "Siparis guncellendi"
                    : "Siparis mutfaga gonderildi",
                  description: `${draftItems.length} kalem mutfak akisina girdi.`,
                  severity: "success",
                },
              );
              submittedTable = nextTable;
              return nextTable;
            }),
          },
          [action.tableId],
        );

        if (!submittedOrder || !submittedTable) {
          return nextState;
        }

        const autoReceiptJob = buildPrinterJob({
          venueId: state.meta.venueId,
          table: submittedTable,
          order: submittedOrder,
          printType: "adisyon",
          requestedBy: action.actor?.name ?? "Restaurant Ops",
          source: "auto_on_submit",
        });

        return {
          ...nextState,
          printerJobs: [autoReceiptJob, ...nextState.printerJobs],
          tables: nextState.tables.map((table) =>
            table.id === action.tableId
              ? addLog(table, {
                  type: "print",
                  title: "Adisyon kaydi olusturuldu",
                  description: `${submittedOrder?.label ?? "Siparis"} icin adisyon job'i olusturuldu.`,
                  severity: "info",
                })
              : table,
          ),
        };
      }
    case "SET_GUEST_COUNT":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) =>
            table.id === action.tableId
              ? {
                  ...table,
                  guestCount: action.guestCount,
                  lastActionAt: action.createdAt,
                }
              : table,
          ),
        },
        [action.tableId],
      );
    case "ADVANCE_ORDER_STATUS":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) => {
            if (table.id !== action.tableId) return table;
            const next = table.orders.map((order) => {
              if (order.id !== action.orderId) return order;
              const nextStatus = nextOrderStatus(order.status);
              return {
                ...order,
                status: nextStatus,
                updatedAt: action.createdAt,
                items: order.items.map((item) => ({ ...item, status: nextStatus })),
              };
            });
            return addLog(
              {
                ...table,
                orders: next.map((order) => ({
                  ...order,
                  totalPrice: calculateOrderTotal(order),
                })),
              },
              {
                type: "order_status",
                title: "Siparis durumu guncellendi",
                description: "Siparis bir sonraki operasyon adimina ilerledi.",
                severity: "info",
              },
            );
          }),
        },
        [action.tableId],
      );
    case "UPDATE_ORDER_ITEM":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) => {
            if (table.id !== action.tableId) return table;
            const orders = table.orders.map((order) => {
              if (order.id !== action.orderId) return order;
              const items = order.items.map((item) =>
                item.id === action.itemId
                  ? {
                      ...item,
                      ...action.updates,
                      customizations: {
                        ...item.customizations,
                        ...action.updates.customizations,
                        modifiers:
                          action.updates.customizations?.modifiers ??
                          item.customizations.modifiers,
                      },
                      totalPrice: calculateOrderItemTotal({
                        ...item,
                        ...action.updates,
                        customizations: {
                          ...item.customizations,
                          ...action.updates.customizations,
                          modifiers:
                            action.updates.customizations?.modifiers ??
                            item.customizations.modifiers,
                        },
                      }),
                    }
                  : item,
              );
              return {
                ...order,
                items,
                updatedAt: action.createdAt,
                totalPrice: calculateOrderTotal({ ...order, items }),
              };
            });
            return { ...table, orders, lastActionAt: action.createdAt };
          }),
        },
        [action.tableId],
      );
    case "REMOVE_ORDER_ITEM":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) => {
            if (table.id !== action.tableId) return table;
            const orders = table.orders
              .map((order) => {
                if (order.id !== action.orderId) return order;
                const items = order.items.filter((item) => item.id !== action.itemId);
                return {
                  ...order,
                  items,
                  totalPrice: calculateOrderTotal({ ...order, items }),
                };
              })
              .filter((order) => order.items.length > 0);
            return addLog(
              { ...table, orders },
              {
                type: "order_remove_item",
                title: "Aktif siparis satiri silindi",
                description: "Secili urun aktif siparisten kaldirildi.",
                severity: "warning",
              },
            );
          }),
        },
        [action.tableId],
      );
    case "ADD_PARTIAL_PAYMENT":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) => {
            if (table.id !== action.tableId) return table;
            return addLog(
              {
                ...table,
                payments: [
                  {
                    id: makeId("pay"),
                    amount: action.amount,
                    method: action.method,
                    createdAt: action.createdAt,
                    kind: action.kind ?? "partial",
                    note: action.note,
                  },
                  ...table.payments,
                ],
                orders:
                  action.kind === "closing"
                    ? table.orders.map((order) => ({
                        ...order,
                        status: "completed",
                        items: order.items.map((item) => ({
                          ...item,
                          status: "completed",
                        })),
                      }))
                    : table.orders,
              },
              {
                type: action.kind === "closing" ? "bill_closed" : "partial_payment",
                title: action.kind === "closing" ? "Hesap kapatildi" : "Ara odeme alindi",
                description:
                  action.kind === "closing"
                    ? "Masa odeme ile tamamlandi."
                    : `${action.amount.toFixed(2)} TL ara odeme alindi.`,
                severity: "success",
              },
            );
          }),
        },
        [action.tableId],
      );
    case "ASSIGN_CUSTOMER":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) =>
            table.id === action.tableId
              ? {
                  ...table,
                  customerId: action.customerId,
                  lastActionAt: action.createdAt,
                }
              : table,
          ),
        },
        [action.tableId],
      );
    case "CREATE_CUSTOMER_AND_ASSIGN": {
      const customerId = makeId("cust");
      const nextCustomer: Customer = {
        ...action.customer,
        id: customerId,
        lastVisitAt: action.createdAt,
        visitCount: 1,
        averageSpend: 0,
        version: 1,
      };
      return finalizeState(
        {
          ...state,
          customers: [nextCustomer, ...state.customers],
          tables: state.tables.map((table) =>
            table.id === action.tableId
              ? {
                  ...table,
                  customerId,
                  lastActionAt: action.createdAt,
                }
              : table,
          ),
        },
        [action.tableId],
      );
    }
    case "CREATE_SPLIT_PLAN":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) =>
            table.id === action.tableId
              ? addLog(
                  {
                    ...table,
                    splitPlans: [action.plan, ...table.splitPlans],
                  },
                  {
                    type: "split_plan",
                    title: "Fis bolme plani olusturuldu",
                    description: `${action.plan.parts.length} parcali odeme plani hazir.`,
                    severity: "success",
                  },
                )
              : table,
          ),
        },
        [action.tableId],
      );
    case "TRANSFER_TABLE": {
      const source = state.tables.find((table) => table.id === action.sourceTableId);
      const target = state.tables.find((table) => table.id === action.targetTableId);
      if (!source || !target) return state;
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) => {
            if (table.id === source.id) {
              const nextSource =
                action.mode === "draft-only"
                  ? {
                      ...table,
                      draft: {
                        items: [],
                        editingOrderId: null,
                        updatedAt: action.createdAt,
                      },
                    }
                  : {
                      ...table,
                      guestCount: 0,
                      customerId: null,
                      draft: {
                        items: [],
                        editingOrderId: null,
                        updatedAt: action.createdAt,
                      },
                      orders: [],
                      payments: [],
                      splitPlans: [],
                      referenceCode: undefined,
                      barcode: undefined,
                      timedBilling: table.timedBilling
                        ? { ...table.timedBilling, enabled: false }
                        : undefined,
                    };
              return addLog(nextSource, {
                type: "transfer_out",
                title: "Masa aktarildi",
                description: `${target.name} masasına ${applyTransferModeLabel(
                  action.mode,
                ).toLowerCase()} akisi uygulandi.`,
                severity: "warning",
              });
            }
            if (table.id === target.id) {
              const mergedDraft =
                action.mode === "all" || action.mode === "merge" || action.mode === "draft-only"
                  ? [...table.draft.items, ...source.draft.items.map(cloneOrderItem)]
                  : table.draft.items;
              const mergedOrders =
                action.mode === "all"
                  ? source.orders.map((order) => ({
                      ...order,
                      label: `${source.name} / ${order.label}`,
                    }))
                  : action.mode === "merge"
                    ? [
                        ...table.orders,
                        ...source.orders.map((order) => ({
                          ...order,
                          label: `${source.name} / ${order.label}`,
                        })),
                      ]
                    : table.orders;
              const nextTarget = {
                ...table,
                guestCount:
                  action.mode === "all" || action.mode === "merge"
                    ? table.guestCount + source.guestCount
                    : table.guestCount,
                customerId:
                  table.customerId ??
                  (action.mode === "all" ? source.customerId : table.customerId),
                draft: {
                  ...table.draft,
                  items: mergedDraft,
                  updatedAt: action.createdAt,
                },
                orders: mergedOrders,
                payments:
                  action.mode === "merge"
                    ? [...table.payments, ...source.payments]
                    : action.mode === "all"
                      ? [...source.payments]
                      : table.payments,
              };
              return addLog(nextTarget, {
                type: "transfer_in",
                title: "Masa aktarimi tamamlandi",
                description: `${source.name} verisi bu masaya guvenli sekilde aktarildi.`,
                severity: "success",
              });
            }
            return table;
          }),
        },
        [action.sourceTableId, action.targetTableId],
      );
    }
    case "MOVE_ORDER_ITEMS": {
      const source = state.tables.find((table) => table.id === action.sourceTableId);
      const target = state.tables.find((table) => table.id === action.targetTableId);
      if (!source || !target) return state;
      const movingItems = source.orders.flatMap((order) =>
        order.items
          .filter((item) => action.itemIds.includes(item.id))
          .map((item) => ({ ...cloneOrderItem(item), status: "draft" as const })),
      );
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) => {
            if (table.id === source.id) {
              const orders = table.orders
                .map((order) => {
                  const items = order.items.filter((item) => !action.itemIds.includes(item.id));
                  return {
                    ...order,
                    items,
                    totalPrice: calculateOrderTotal({ ...order, items }),
                  };
                })
                .filter((order) => order.items.length > 0);
              return addLog(
                {
                  ...table,
                  orders,
                },
                {
                  type: "move_out",
                  title: "Hareket aktarildi",
                  description: `${movingItems.length} satir diger masaya aktarildi.`,
                  severity: "warning",
                },
              );
            }
            if (table.id === target.id) {
              return addLog(
                {
                  ...table,
                  draft: {
                    ...table.draft,
                    items: [...table.draft.items, ...movingItems],
                    updatedAt: action.createdAt,
                  },
                },
                {
                  type: "move_in",
                  title: "Aktarilan hareketler taslaga dustu",
                  description: `${source.name} masasindan gelen satirlar taslaga eklendi.`,
                  severity: "success",
                },
              );
            }
            return table;
          }),
        },
        [action.sourceTableId, action.targetTableId],
      );
    }
    case "REGISTER_PRINT":
      {
        const table = state.tables.find((entry) => entry.id === action.tableId);
        if (!table) {
          return state;
        }
        const activeOrder = table.orders[0];
        const fallbackOrder: TableOrder = activeOrder ?? {
          id: makeId("order"),
          label: "Taslak Ciktisi",
          status: "draft",
          items: table.draft.items.map(cloneOrderItem),
          totalPrice: table.draft.items.reduce(
            (sum, item) => sum + calculateOrderItemTotal(item),
            0,
          ),
          createdAt: action.createdAt,
          updatedAt: action.createdAt,
          source: "waiter",
          version: 1,
        };
        const printType = action.printType.toLowerCase().includes("mutf")
          ? "mutfak"
          : "adisyon";
        const nextState = finalizeState(
          {
            ...state,
            printerJobs: [
              buildPrinterJob({
                venueId: state.meta.venueId,
                table,
                order: fallbackOrder,
                printType,
                requestedBy: action.actor?.name ?? "Restaurant Ops",
                source: "manual_action",
              }),
              ...state.printerJobs,
            ],
            tables: state.tables.map((entry) =>
              entry.id === action.tableId
                ? addLog(entry, {
                    type: "print",
                    title: "Yazdirma islemi",
                    description: `${action.printType} yazdirma aksiyonu tetiklendi.`,
                    severity: "info",
                  })
                : entry,
            ),
          },
          [action.tableId],
        );
        return nextState;
      }
    case "CLOSE_BILL":
      return applyRestaurantMutation(state, {
        type: "ADD_PARTIAL_PAYMENT",
        tableId: action.tableId,
        amount: action.amount,
        method: action.method,
        note: action.note,
        kind: "closing",
        clientMutationId: action.clientMutationId,
        actor: action.actor,
        createdAt: action.createdAt,
        expectedTableVersion: action.expectedTableVersion,
      });
    case "NEW_BILL":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) =>
            table.id === action.tableId
              ? addLog(
                  {
                    ...table,
                    guestCount: 0,
                    customerId: null,
                    draft: {
                      items: [],
                      editingOrderId: null,
                      updatedAt: action.createdAt,
                    },
                    orders: [],
                    payments: [],
                    splitPlans: [],
                    referenceCode: undefined,
                    barcode: undefined,
                    timedBilling: table.timedBilling
                      ? { ...table.timedBilling, enabled: false }
                      : undefined,
                  },
                  {
                    type: "new_bill",
                    title: "Yeni fis acildi",
                    description: "Masa yeni servis icin sifirlandi.",
                    severity: "success",
                  },
                )
              : table,
          ),
        },
        [action.tableId],
      );
    case "SET_REFERENCE_CODE":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) =>
            table.id === action.tableId
              ? { ...table, referenceCode: action.code, lastActionAt: action.createdAt }
              : table,
          ),
        },
        [action.tableId],
      );
    case "SET_BARCODE":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) =>
            table.id === action.tableId
              ? { ...table, barcode: action.code, lastActionAt: action.createdAt }
              : table,
          ),
        },
        [action.tableId],
      );
    case "SET_TIMED_BILLING":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) =>
            table.id === action.tableId
              ? {
                  ...table,
                  timedBilling: action.timedBilling,
                  lastActionAt: action.createdAt,
                }
              : table,
          ),
        },
        [action.tableId],
      );
    case "ADD_LOG":
      return finalizeState(
        {
          ...state,
          tables: state.tables.map((table) =>
            table.id === action.tableId
              ? addLog(table, {
                  type: action.typeKey,
                  title: action.title,
                  description: action.description,
                  severity: "info",
                })
              : table,
          ),
        },
        [action.tableId],
      );
    default:
      return state;
  }
}

export function extractChangedTables(
  action: RestaurantMutationInput,
): string[] {
  if ("sourceTableId" in action && "targetTableId" in action) {
    return [action.sourceTableId, action.targetTableId];
  }
  return "tableId" in action ? [action.tableId] : [];
}
