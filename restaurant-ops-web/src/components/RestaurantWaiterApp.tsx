"use client";

import {
  useDeferredValue,
  useEffect,
  useRef,
  useState,
  useTransition,
} from "react";
import { usePathname, useRouter } from "next/navigation";
import { CustomerSelectorModal } from "@/components/customers/CustomerSelectorModal";
import { OperationsDrawer } from "@/components/operations/OperationsDrawer";
import { PartialPaymentModal } from "@/components/operations/PartialPaymentModal";
import { SplitBillModal } from "@/components/operations/SplitBillModal";
import { TransferTableModal } from "@/components/operations/TransferTableModal";
import { PrintActionsPanel } from "@/components/printing/PrintActionsPanel";
import { ProductCustomizeModal } from "@/components/products/ProductCustomizeModal";
import { ServiceBuilderModal } from "@/components/products/ServiceBuilderModal";
import { ToastProvider, useToast } from "@/components/providers/ToastProvider";
import { TableCard } from "@/components/tables/TableCard";
import { TableDetailsModal } from "@/components/tables/TableDetailsModal";
import { Button } from "@/components/ui/Button";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import { EmptyState } from "@/components/ui/EmptyState";
import { Panel } from "@/components/ui/Panel";
import {
  RestaurantMutationDraft,
} from "@/features/restaurant/domain/commands";
import {
  OrderItem,
  Product,
  RestaurantStoreState,
  RestaurantTable,
  TableOrder,
} from "@/lib/types";
import {
  buildProductOrderItem,
  calculateOrderItemTotal,
  calculateRemainingTotal,
  getActiveOrders,
} from "@/lib/restaurant";
import { WaiterStoreProvider, useWaiterStore } from "@/state/waiter-store";
import { formatCurrency } from "@/lib/utils";

type ModalSource = "draft" | "active";
type DetailTab = "products" | "reservation" | "order";

interface EditingState {
  open: boolean;
  product: Product | null;
  initialItem: OrderItem | null;
  orderId: string | null;
  source: ModalSource;
}

interface ConfirmState {
  open: boolean;
  title: string;
  description: string;
  confirmLabel?: string;
  tone?: "default" | "danger";
  onConfirm?: () => void;
}

export function RestaurantWaiterApp({
  initialState,
  initialTableId,
}: {
  initialState: RestaurantStoreState;
  initialTableId?: string;
}) {
  return (
    <WaiterStoreProvider initialState={initialState}>
      <ToastProvider>
        <RestaurantWaiterScreen initialTableId={initialTableId} />
      </ToastProvider>
    </WaiterStoreProvider>
  );
}

function RestaurantWaiterScreen({
  initialTableId,
}: {
  initialTableId?: string;
}) {
  const {
    state,
    applyLocalMutation,
    executeMutation,
    retryLastMutation,
    refresh,
    isLoading,
    isMutating,
    dirtyTableIds,
    lastError,
    discardLocalChanges,
  } = useWaiterStore();
  const { pushToast } = useToast();
  const router = useRouter();
  const pathname = usePathname();
  const [isRouting, startRouteTransition] = useTransition();
  const errorFingerprintRef = useRef<string | null>(null);

  const [selectedTableId, setSelectedTableId] = useState<string | null>(
    initialTableId ?? null,
  );
  const [operationsOpen, setOperationsOpen] = useState(false);
  const [detailTab, setDetailTab] = useState<DetailTab>(
    initialTableId ? "order" : "products",
  );
  const [submittingDraftTableId, setSubmittingDraftTableId] = useState<string | null>(
    null,
  );
  const [productModal, setProductModal] = useState<EditingState>({
    open: false,
    product: null,
    initialItem: null,
    orderId: null,
    source: "draft",
  });
  const [serviceModal, setServiceModal] = useState<EditingState>({
    open: false,
    product: null,
    initialItem: null,
    orderId: null,
    source: "draft",
  });
  const [partialPaymentOpen, setPartialPaymentOpen] = useState(false);
  const [splitBillOpen, setSplitBillOpen] = useState(false);
  const [transferOpen, setTransferOpen] = useState(false);
  const [customerModal, setCustomerModal] = useState<{
    open: boolean;
    mode: "select" | "create";
  }>({ open: false, mode: "select" });
  const [printPanel, setPrintPanel] = useState<{
    open: boolean;
    type: "adisyon" | "mutfak";
  }>({ open: false, type: "adisyon" });
  const [tableQuery, setTableQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [confirm, setConfirm] = useState<ConfirmState>({
    open: false,
    title: "",
    description: "",
  });

  const deferredTableQuery = useDeferredValue(tableQuery);
  const lastVisibleTableRef = useRef<RestaurantTable | null>(null);

  useEffect(() => {
    setSelectedTableId(initialTableId ?? null);
    setDetailTab(initialTableId ? "order" : "products");
  }, [initialTableId]);

  useEffect(() => {
    if (!lastError) return;
    const fingerprint = `${lastError.code}:${lastError.message}`;
    if (errorFingerprintRef.current === fingerprint) return;
    errorFingerprintRef.current = fingerprint;
    pushToast({
      title: "Islem geri alindi",
      description: lastError.message,
      tone: "error",
    });
  }, [lastError, pushToast]);

  const selectedTable =
    state.tables.find((table) => table.id === selectedTableId) ?? null;
  if (selectedTable) {
    lastVisibleTableRef.current = selectedTable;
  } else if (!selectedTableId) {
    lastVisibleTableRef.current = null;
  }
  const visibleSelectedTable =
    selectedTable ??
    (selectedTableId && lastVisibleTableRef.current?.id === selectedTableId
      ? lastVisibleTableRef.current
      : null);

  const activeTableCount = state.tables.filter(
    (table) => table.status !== "empty" && table.status !== "completed",
  ).length;
  const activeTicketCount = state.tables.reduce(
    (sum, table) => sum + getActiveOrders(table).length,
    0,
  );
  const draftCount = state.tables.reduce(
    (sum, table) => sum + table.draft.items.length,
    0,
  );
  const receivableTotal = state.tables.reduce(
    (sum, table) => sum + calculateRemainingTotal(table),
    0,
  );

  const filteredTables = state.tables.filter((table) => {
    const matchesFilter = statusFilter === "all" || table.status === statusFilter;
    const matchesQuery =
      deferredTableQuery.trim().length === 0 ||
      [table.name, table.zone, table.referenceCode ?? ""]
        .join(" ")
        .toLowerCase()
        .includes(deferredTableQuery.trim().toLowerCase());
    return matchesFilter && matchesQuery;
  });

  function openTable(tableId: string) {
    setSelectedTableId(tableId);
    setDetailTab("order");
    startRouteTransition(() => {
      const nextPath = `/waiter/tables/${tableId}`;
      if (pathname !== nextPath) {
        router.push(nextPath);
      }
    });
  }

  function closeTable() {
    setSelectedTableId(null);
    setDetailTab("products");
    setOperationsOpen(false);
    startRouteTransition(() => {
      if (pathname !== "/waiter") {
        router.push("/waiter");
      }
    });
  }

  function requestConfirmation(
    title: string,
    description: string,
    onConfirm: () => void,
    tone: "default" | "danger" = "default",
    confirmLabel = "Onayla",
  ) {
    setConfirm({
      open: true,
      title,
      description,
      onConfirm,
      tone,
      confirmLabel,
    });
  }

  function openEditor(
    product: Product,
    source: ModalSource,
    initialItem: OrderItem | null = null,
    orderId: string | null = null,
  ) {
    if (product.kind === "service") {
      setServiceModal({
        open: true,
        product,
        initialItem,
        orderId,
        source,
      });
      return;
    }
    setProductModal({
      open: true,
      product,
      initialItem,
      orderId,
      source,
    });
  }

  function applyLocal(mutation: RestaurantMutationDraft) {
    applyLocalMutation(mutation);
  }

  async function runRemote(
    mutation: RestaurantMutationDraft,
    options?: {
      optimistic?: boolean;
      successToast?: { title: string; description?: string; tone?: "success" | "info" | "warning" | "error" };
      onSuccess?: () => void;
    },
  ) {
    try {
      const result = await executeMutation(mutation, {
        optimistic: options?.optimistic,
      });
      if (options?.successToast) {
        pushToast({
          title: options.successToast.title,
          description: options.successToast.description,
          tone: options.successToast.tone ?? "success",
        });
      }
      options?.onSuccess?.();
      return result;
    } catch {
      return null;
    }
  }

  function addDraftItem(product: Product, item?: OrderItem) {
    if (!selectedTable) return;
    applyLocal({
      type: "ADD_DRAFT_ITEM",
      tableId: selectedTable.id,
      item: item ?? buildProductOrderItem(product),
    });
    pushToast({
      title: "Taslak guncellendi",
      description: `${product.name} ${selectedTable.name} taslagina eklendi.`,
      tone: "success",
    });
  }

  function handleEditorConfirm(item: OrderItem, modal: EditingState) {
    if (!selectedTable || !modal.product) return;
    if (modal.source === "draft") {
      if (modal.initialItem) {
        applyLocal({
          type: "UPDATE_DRAFT_ITEM",
          tableId: selectedTable.id,
          itemId: modal.initialItem.id,
          updates: item,
        });
      } else {
        applyLocal({
          type: "ADD_DRAFT_ITEM",
          tableId: selectedTable.id,
          item,
        });
      }
      pushToast({
        title: "Ozellestirme kaydedildi",
        description: `${item.name} satiri guncellendi.`,
        tone: "success",
      });
    } else if (modal.orderId) {
      void runRemote(
        {
          type: "UPDATE_ORDER_ITEM",
          tableId: selectedTable.id,
          orderId: modal.orderId,
          itemId: modal.initialItem?.id ?? item.id,
          updates: item,
        },
        {
          successToast: {
            title: "Aktif siparis guncellendi",
            description: `${item.name} satiri kaydedildi.`,
            tone: "success",
          },
        },
      );
    }
    setProductModal({
      open: false,
      product: null,
      initialItem: null,
      orderId: null,
      source: "draft",
    });
    setServiceModal({
      open: false,
      product: null,
      initialItem: null,
      orderId: null,
      source: "draft",
    });
  }

  async function handleRefresh() {
    try {
      await refresh();
      pushToast({
        title: "Snapshot yenilendi",
        description: "Sunucudaki en guncel operasyon durumu alindi.",
        tone: "info",
      });
    } catch {
      return;
    }
  }

  async function handleRetry() {
    try {
      const result = await retryLastMutation();
      if (!result) {
        pushToast({
          title: "Tekrar denenecek islem yok",
          tone: "warning",
        });
        return;
      }
      pushToast({
        title: "Islem tekrar denendi",
        description: "Kritik mutation guncel revision ile yeniden gonderildi.",
        tone: "success",
      });
    } catch {
      return;
    }
  }

  async function handleSubmitDraft() {
    if (!visibleSelectedTable) return;
    const tableId = visibleSelectedTable.id;
    const tableName = visibleSelectedTable.name;
    const draftSnapshot = structuredClone(visibleSelectedTable.draft);

    setDetailTab("order");
    setSubmittingDraftTableId(tableId);

    try {
      await executeMutation(
        {
          type: "SEND_DRAFT",
          tableId,
          draft: draftSnapshot,
        },
        {
          optimistic: false,
        },
      );

      setSelectedTableId(tableId);
      pushToast({
        title: draftSnapshot.editingOrderId
          ? "Siparis guncellendi"
          : "Siparis mutfaga iletildi",
        description: `${tableName} icin aktif siparis ayni ekranda olusturuldu.`,
        tone: "success",
      });
    } catch {
      return;
    } finally {
      setSubmittingDraftTableId(null);
    }
  }

  return (
    <div className="min-h-screen px-3 py-4 md:px-6 md:py-6">
      <div className="mx-auto max-w-[1600px] space-y-6">
        <section className="grid gap-4 xl:grid-cols-[1.25fr,0.75fr]">
          <Panel className="overflow-hidden bg-gradient-to-br from-slate-950 via-slate-900 to-violet-900 p-6 text-white">
            <div className="max-w-3xl">
              <div className="text-xs uppercase tracking-[0.22em] text-white/50">
                Garson - Masa Siparisleri
              </div>
              <h1 className="mt-3 text-4xl font-semibold tracking-tight md:text-5xl">
                Demo arayuzden production omurgasina gecen restoran operasyon modulu
              </h1>
              <p className="mt-4 max-w-2xl text-base leading-7 text-white/72">
                Route bazli acilis, optimistic update, rollback, conflict kontrolu
                ve repository adapter yapisi ile garson ekranini gercek veri katmanina
                yaklastirdik. Kritik operasyonlar transaction mantigina hazir.
              </p>
              <div className="mt-6 flex flex-wrap gap-3">
                <Button
                  variant="secondary"
                  size="lg"
                  onClick={() => {
                    const firstBusyTable =
                      state.tables.find((table) => table.status !== "empty") ??
                      state.tables[0];
                    openTable(firstBusyTable.id);
                  }}
                >
                  Operasyona Basla
                </Button>
                <Button variant="soft" size="lg">
                  {state.meta.source === "supabase" ? "Supabase Omurgasi" : "Mock + API Adapter"}
                </Button>
              </div>
            </div>
          </Panel>

          <Panel className="p-5">
            <div className="grid gap-3 sm:grid-cols-2">
              <StatCard label="Aktif masa" value={`${activeTableCount}`} helper="Canli servis" />
              <StatCard label="Acilik fis" value={`${activeTicketCount}`} helper="Aktif siparis" />
              <StatCard label="Bekleyen taslak" value={`${draftCount}`} helper="UI workspace" />
              <StatCard
                label="Tahsilat beklentisi"
                value={formatCurrency(receivableTotal)}
                helper="Kalan tutar"
              />
            </div>
          </Panel>
        </section>

        <Panel className="p-4">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <div className="text-lg font-semibold text-slate-950">Runtime durumu</div>
              <div className="mt-1 text-sm text-slate-500">
                Backend kaynak: {state.meta.source} • Snapshot {state.meta.snapshotVersion}
              </div>
            </div>
            <div className="flex flex-wrap gap-2">
              <RuntimeChip
                label={isLoading ? "Yukleniyor" : "Hazir"}
                tone={isLoading ? "amber" : "emerald"}
              />
              <RuntimeChip
                label={isMutating || isRouting ? "Senkronize oluyor" : "Stabil"}
                tone={isMutating || isRouting ? "violet" : "slate"}
              />
              <RuntimeChip
                label={`${dirtyTableIds.length} yerel degisiklik`}
                tone={dirtyTableIds.length > 0 ? "amber" : "slate"}
              />
              {dirtyTableIds.length > 0 ? (
                <Button variant="ghost" size="sm" onClick={() => discardLocalChanges()}>
                  Yerel Degisiklikleri Geri Al
                </Button>
              ) : null}
              <Button variant="ghost" size="sm" onClick={() => void handleRefresh()}>
                Snapshot Yenile
              </Button>
              {lastError?.retriable ? (
                <Button variant="secondary" size="sm" onClick={() => void handleRetry()}>
                  Son Islemi Tekrar Dene
                </Button>
              ) : null}
            </div>
          </div>
        </Panel>

        <Panel className="p-4">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <div className="text-lg font-semibold text-slate-950">Masa listesi</div>
              <div className="text-sm text-slate-500">
                Garsonun bakar bakmaz masa durumu, sure ve tutari anlamasi icin sadeletildi.
              </div>
            </div>
            <div className="flex w-full flex-col gap-3 sm:flex-row lg:w-auto">
              <input
                value={tableQuery}
                onChange={(event) => setTableQuery(event.target.value)}
                placeholder="Masa ara..."
                className="h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm outline-none focus:border-violet-300 sm:min-w-[240px]"
              />
              <div className="flex flex-wrap gap-2">
                {[
                  { id: "all", label: "Tum" },
                  { id: "active", label: "Aktif" },
                  { id: "preparing", label: "Hazirlaniyor" },
                  { id: "payment_pending", label: "Odeme" },
                  { id: "empty", label: "Bos" },
                ].map((entry) => {
                  const active = statusFilter === entry.id;
                  return (
                    <button
                      key={entry.id}
                      onClick={() => setStatusFilter(entry.id)}
                      className={`rounded-2xl px-4 py-2.5 text-sm font-medium ${
                        active
                          ? "bg-slate-950 text-white"
                          : "border border-slate-200 bg-white text-slate-600"
                      }`}
                    >
                      {entry.label}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        </Panel>

        {filteredTables.length === 0 ? (
          <EmptyState
            title="Bu filtrede masa bulunamadi"
            description="Arama veya durum filtresi sonuc vermedi. Yogun saatte gereksiz bosluk olusturmamak icin yalnizca net sonuc gosteriliyor."
          />
        ) : (
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {filteredTables.map((table) => (
              <TableCard
                key={table.id}
                table={table}
                selected={selectedTableId === table.id}
                onOpen={() => openTable(table.id)}
              />
            ))}
          </div>
        )}
      </div>

      <TableDetailsModal
        open={!!visibleSelectedTable}
        table={visibleSelectedTable}
        activeTab={detailTab}
        onTabChange={(tab) => setDetailTab(tab as DetailTab)}
        isSubmittingDraft={submittingDraftTableId === visibleSelectedTable?.id}
        products={state.products}
        categories={state.categories.filter((category) => category.id !== "popular")}
        customers={state.customers}
        onClose={closeTable}
        onOpenOperations={() => setOperationsOpen(true)}
        onQuickAddProduct={(product) => {
          if (product.kind === "service") {
            openEditor(product, "draft");
            return;
          }
          addDraftItem(product);
        }}
        onCustomizeProduct={(product) => openEditor(product, "draft")}
        onQuickWeight={(product, grams) =>
          addDraftItem(
            product,
            buildProductOrderItem(product, {
              customizations: {
                note: "",
                modifiers: [],
                grams,
              },
            }),
          )
        }
        onAdjustDraftQuantity={(item, nextQuantity) =>
          selectedTable &&
          applyLocal({
            type: "UPDATE_DRAFT_ITEM",
            tableId: selectedTable.id,
            itemId: item.id,
            updates: { quantity: nextQuantity },
          })
        }
        onEditDraftItem={(item) => {
          const product = state.products.find((entry) => entry.id === item.productId);
          if (!product) return;
          openEditor(product, "draft", item);
        }}
        onRemoveDraftItem={(item) =>
          selectedTable &&
          requestConfirmation(
            "Taslak satiri silinsin mi?",
            `${item.name} taslaktan kaldirilacak.`,
            () => {
              applyLocal({
                type: "REMOVE_DRAFT_ITEM",
                tableId: selectedTable.id,
                itemId: item.id,
              });
              pushToast({
                title: "Taslak satiri silindi",
                tone: "warning",
              });
              setConfirm({ open: false, title: "", description: "" });
            },
            "danger",
            "Sil",
          )
        }
        onSubmitDraft={() => void handleSubmitDraft()}
        onClearDraft={() =>
          selectedTable &&
          requestConfirmation(
            "Taslak temizlensin mi?",
            "Bekleyen tum taslak satirlar silinecek.",
            () => {
              applyLocal({
                type: "CLEAR_DRAFT",
                tableId: selectedTable.id,
              });
              setConfirm({ open: false, title: "", description: "" });
            },
            "danger",
            "Temizle",
          )
        }
        onAdvanceOrderStatus={(order) => {
          if (!selectedTable) return;
          void runRemote(
            {
              type: "ADVANCE_ORDER_STATUS",
              tableId: selectedTable.id,
              orderId: order.id,
            },
            {
              successToast: {
                title: "Siparis durumu ilerletildi",
                description: `${order.label} bir sonraki adima gecti.`,
                tone: "info",
              },
            },
          );
        }}
        onEditOrder={(order) => {
          if (!selectedTable) return;
          const load = () => {
            applyLocal({
              type: "LOAD_ORDER_INTO_DRAFT",
              tableId: selectedTable.id,
              orderId: order.id,
            });
            pushToast({
              title: "Siparis taslaga alindi",
              description: `${order.label} guncelleme modunda.`,
              tone: "info",
            });
          };

          if (
            selectedTable.draft.items.length > 0 &&
            selectedTable.draft.editingOrderId !== order.id
          ) {
            requestConfirmation(
              "Mevcut taslak degistirilsin mi?",
              "Var olan taslak uzerine yazilacak ve secili aktif siparis guncelleme moduna alinacak.",
              () => {
                load();
                setConfirm({ open: false, title: "", description: "" });
              },
              "danger",
              "Taslaga Al",
            );
            return;
          }

          load();
        }}
        onEditOrderItem={(order, item) => {
          const product = state.products.find((entry) => entry.id === item.productId);
          if (!product) return;
          openEditor(product, "active", item, order.id);
        }}
        onAdjustOrderItemQuantity={(order, item, nextQuantity) =>
          selectedTable &&
          void runRemote(
            {
              type: "UPDATE_ORDER_ITEM",
              tableId: selectedTable.id,
              orderId: order.id,
              itemId: item.id,
              updates: {
                quantity: nextQuantity,
                totalPrice: calculateOrderItemTotal({
                  ...item,
                  quantity: nextQuantity,
                }),
              },
            },
            {
              successToast: {
                title: "Aktif siparis guncellendi",
                description: `${item.name} adedi guncellendi.`,
                tone: "success",
              },
            },
          )
        }
        onRemoveOrderItem={(order, item) =>
          selectedTable &&
          requestConfirmation(
            "Aktif siparis satiri silinsin mi?",
            `${item.name} aktif siparisten kaldirilacak.`,
            () => {
              void runRemote(
                {
                  type: "REMOVE_ORDER_ITEM",
                  tableId: selectedTable.id,
                  orderId: order.id,
                  itemId: item.id,
                },
                {
                  successToast: {
                    title: "Aktif satir silindi",
                    description: `${item.name} aktif siparisten kaldirildi.`,
                    tone: "warning",
                  },
                  onSuccess: () => setConfirm({ open: false, title: "", description: "" }),
                },
              );
            },
            "danger",
            "Sil",
          )
        }
      />

      <OperationsDrawer
        open={operationsOpen}
        table={visibleSelectedTable}
        tables={state.tables}
        onClose={() => setOperationsOpen(false)}
        onOpenPartialPayment={() => setPartialPaymentOpen(true)}
        onOpenSplitBill={() => setSplitBillOpen(true)}
        onOpenTransfer={() => setTransferOpen(true)}
        onOpenPrint={(type) => setPrintPanel({ open: true, type })}
        onOpenCustomerModal={(mode) => setCustomerModal({ open: true, mode })}
        onSetGuestCount={(guestCount) =>
          selectedTable &&
          void runRemote(
            {
              type: "SET_GUEST_COUNT",
              tableId: selectedTable.id,
              guestCount,
            },
            {
              successToast: {
                title: "Musteri sayisi guncellendi",
                tone: "info",
              },
            },
          )
        }
        onNewBill={() =>
          selectedTable &&
          requestConfirmation(
            "Yeni fis acilsin mi?",
            "Masanin mevcut siparis, odeme ve taslak durumu sifirlanacak.",
            () => {
              void runRemote(
                {
                  type: "NEW_BILL",
                  tableId: selectedTable.id,
                },
                {
                  successToast: {
                    title: "Yeni fis acildi",
                    description: `${selectedTable.name} yeni servis icin hazir.`,
                    tone: "success",
                  },
                  onSuccess: () => setConfirm({ open: false, title: "", description: "" }),
                },
              );
            },
            "danger",
            "Yeni Fis Ac",
          )
        }
        onMoveItems={(targetTableId, itemIds) => {
          if (!selectedTable || itemIds.length === 0 || !targetTableId) return;
          void runRemote(
            {
              type: "MOVE_ORDER_ITEMS",
              sourceTableId: selectedTable.id,
              targetTableId,
              itemIds,
            },
            {
              successToast: {
                title: "Hareket aktarildi",
                description: "Secili urunler hedef masa taslagina eklendi.",
                tone: "success",
              },
            },
          );
        }}
        onSetTimedBilling={(enabled, ratePerHour) => {
          if (!selectedTable) return;
          void runRemote(
            {
              type: "SET_TIMED_BILLING",
              tableId: selectedTable.id,
              timedBilling: {
                enabled,
                ratePerHour,
                startedAt:
                  selectedTable.timedBilling?.startedAt ?? new Date().toISOString(),
              },
            },
            {
              successToast: {
                title: "Sureli hesap guncellendi",
                tone: "info",
              },
            },
          );
        }}
        onSetReferenceCode={(code) => {
          if (!selectedTable) return;
          void runRemote(
            {
              type: "SET_REFERENCE_CODE",
              tableId: selectedTable.id,
              code,
            },
            {
              successToast: {
                title: "Ozel kod kaydedildi",
                tone: "success",
              },
            },
          );
        }}
        onSetBarcode={(code) => {
          if (!selectedTable) return;
          void runRemote(
            {
              type: "SET_BARCODE",
              tableId: selectedTable.id,
              code,
            },
            {
              successToast: {
                title: "Barkod kaydedildi",
                tone: "success",
              },
            },
          );
        }}
        onCloseBill={(method, note) => {
          if (!selectedTable) return;
          if (selectedTable.draft.items.length > 0) {
            pushToast({
              title: "Taslak varken hesap kapatilamaz",
              description: "Once bekleyen taslagi gonder veya temizle.",
              tone: "warning",
            });
            return;
          }
          const amount = calculateRemainingTotal(selectedTable);
          if (amount <= 0) {
            pushToast({
              title: "Kapatilacak kalan tutar yok",
              tone: "warning",
            });
            return;
          }
          void runRemote(
            {
              type: "CLOSE_BILL",
              tableId: selectedTable.id,
              method,
              note,
              amount,
            },
            {
              successToast: {
                title: "Hesap kapatildi",
                description: `${selectedTable.name} kapanis odemesi alindi.`,
                tone: "success",
              },
            },
          );
        }}
        onLog={(title, description) =>
          selectedTable &&
          void runRemote(
            {
              type: "ADD_LOG",
              tableId: selectedTable.id,
              typeKey: "tool",
              title,
              description,
            },
            {
              successToast: {
                title: "Operation log kaydedildi",
                tone: "info",
              },
            },
          )
        }
      />

      <ProductCustomizeModal
        open={productModal.open}
        product={productModal.product}
        initialItem={productModal.initialItem}
        onClose={() =>
          setProductModal({
            open: false,
            product: null,
            initialItem: null,
            orderId: null,
            source: "draft",
          })
        }
        onConfirm={(item) => handleEditorConfirm(item, productModal)}
      />

      <ServiceBuilderModal
        open={serviceModal.open}
        product={serviceModal.product}
        products={state.products}
        initialItem={serviceModal.initialItem}
        onClose={() =>
          setServiceModal({
            open: false,
            product: null,
            initialItem: null,
            orderId: null,
            source: "draft",
          })
        }
        onConfirm={(item) => handleEditorConfirm(item, serviceModal)}
      />

      <PartialPaymentModal
        open={partialPaymentOpen}
        table={visibleSelectedTable}
        onClose={() => setPartialPaymentOpen(false)}
        onSubmit={(amount, method, note) => {
          if (!selectedTable || amount <= 0) return;
          void runRemote(
            {
              type: "ADD_PARTIAL_PAYMENT",
              tableId: selectedTable.id,
              amount,
              method,
              note,
            },
            {
              successToast: {
                title: "Ara odeme kaydedildi",
                description: `${formatCurrency(amount)} tahsil edildi.`,
                tone: "success",
              },
              onSuccess: () => setPartialPaymentOpen(false),
            },
          );
        }}
      />

      <SplitBillModal
        open={splitBillOpen}
        table={visibleSelectedTable}
        onClose={() => setSplitBillOpen(false)}
        onCreatePlan={(plan) => {
          if (!selectedTable) return;
          void runRemote(
            {
              type: "CREATE_SPLIT_PLAN",
              tableId: selectedTable.id,
              plan,
            },
            {
              successToast: {
                title: "Fis bolme plani olusturuldu",
                description: `${plan.parts.length} parcali plan hazir.`,
                tone: "success",
              },
              onSuccess: () => setSplitBillOpen(false),
            },
          );
        }}
      />

      <TransferTableModal
        open={transferOpen}
        sourceTable={visibleSelectedTable}
        tables={state.tables}
        onClose={() => setTransferOpen(false)}
        onConfirm={(targetTableId, mode) => {
          if (!selectedTable) return;
          void runRemote(
            {
              type: "TRANSFER_TABLE",
              sourceTableId: selectedTable.id,
              targetTableId,
              mode,
            },
            {
              successToast: {
                title: "Masa aktarimi tamamlandi",
                description: "Kartlar ve siparis akisi aninda guncellendi.",
                tone: "success",
              },
              onSuccess: () => {
                setTransferOpen(false);
                setOperationsOpen(false);
                openTable(targetTableId);
              },
            },
          );
        }}
      />

      <CustomerSelectorModal
        open={customerModal.open}
        mode={customerModal.mode}
        customers={state.customers}
        currentCustomerId={visibleSelectedTable?.customerId}
        onClose={() => setCustomerModal({ open: false, mode: "select" })}
        onSelect={(customerId) => {
          if (!selectedTable) return;
          void runRemote(
            {
              type: "ASSIGN_CUSTOMER",
              tableId: selectedTable.id,
              customerId,
            },
            {
              successToast: {
                title: customerId
                  ? "Musteri atandi"
                  : "Musteri baglantisi kaldirildi",
                tone: "success",
              },
              onSuccess: () => setCustomerModal({ open: false, mode: "select" }),
            },
          );
        }}
        onCreate={(payload) => {
          if (!selectedTable) return;
          void runRemote(
            {
              type: "CREATE_CUSTOMER_AND_ASSIGN",
              tableId: selectedTable.id,
              customer: payload,
            },
            {
              successToast: {
                title: "Yeni musteri olusturuldu",
                description: `${payload.name} masaya baglandi.`,
                tone: "success",
              },
              onSuccess: () => setCustomerModal({ open: false, mode: "select" }),
            },
          );
        }}
      />

      <PrintActionsPanel
        open={printPanel.open}
        table={visibleSelectedTable}
        printerJobs={state.printerJobs}
        initialType={printPanel.type}
        onClose={() => setPrintPanel({ open: false, type: "adisyon" })}
        onPrint={(type) => {
          if (!selectedTable) return;
          void runRemote(
            {
              type: "REGISTER_PRINT",
              tableId: selectedTable.id,
              printType: type === "adisyon" ? "Adisyon Yazdir" : "Mutfaga Yazdir",
            },
            {
              successToast: {
                title:
                  type === "adisyon" ? "Adisyon yazdirildi" : "Mutfak cikti hazir",
                tone: "success",
              },
              onSuccess: () => setPrintPanel({ open: false, type: "adisyon" }),
            },
          );
        }}
      />

      <ConfirmDialog
        open={confirm.open}
        title={confirm.title}
        description={confirm.description}
        tone={confirm.tone}
        confirmLabel={confirm.confirmLabel}
        onCancel={() => setConfirm({ open: false, title: "", description: "" })}
        onConfirm={() => confirm.onConfirm?.()}
      />
    </div>
  );
}

function StatCard({
  label,
  value,
  helper,
}: {
  label: string;
  value: string;
  helper: string;
}) {
  return (
    <div className="rounded-[24px] bg-slate-50 p-4">
      <div className="text-xs uppercase tracking-[0.18em] text-slate-400">{label}</div>
      <div className="mt-2 text-2xl font-semibold text-slate-950">{value}</div>
      <div className="mt-1 text-sm text-slate-500">{helper}</div>
    </div>
  );
}

function RuntimeChip({
  label,
  tone,
}: {
  label: string;
  tone: "emerald" | "amber" | "violet" | "slate";
}) {
  const className =
    tone === "emerald"
      ? "bg-emerald-50 text-emerald-800"
      : tone === "amber"
        ? "bg-amber-50 text-amber-800"
        : tone === "violet"
          ? "bg-violet-50 text-violet-800"
          : "bg-slate-100 text-slate-700";

  return (
    <span className={`rounded-full px-3 py-1.5 text-xs font-medium ${className}`}>
      {label}
    </span>
  );
}
