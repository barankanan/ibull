"use client";

import { ActiveOrdersPanel } from "@/components/orders/ActiveOrdersPanel";
import { OrderDraftPanel } from "@/components/orders/OrderDraftPanel";
import { ProductGrid } from "@/components/products/ProductGrid";
import { TableStatusBadge } from "@/components/tables/TableStatusBadge";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { ModalShell } from "@/components/ui/ModalShell";
import { Panel } from "@/components/ui/Panel";
import { StatusTimeline } from "@/components/ui/StatusTimeline";
import { Tabs } from "@/components/ui/Tabs";
import {
  calculateDraftTotal,
  calculateGrossTotal,
  calculateRemainingTotal,
  findCustomerById,
  getActiveOrders,
  getTopSuggestions,
} from "@/lib/restaurant";
import {
  Customer,
  OrderItem,
  Product,
  ProductCategory,
  RestaurantTable,
  TableOrder,
} from "@/lib/types";
import {
  formatClock,
  formatCurrency,
  formatElapsedMinutes,
  formatShortDate,
} from "@/lib/utils";

interface TableDetailsModalProps {
  open: boolean;
  table: RestaurantTable | null;
  activeTab: string;
  onTabChange: (tab: string) => void;
  isSubmittingDraft?: boolean;
  products: Product[];
  categories: ProductCategory[];
  customers: Customer[];
  onClose: () => void;
  onOpenOperations: () => void;
  onQuickAddProduct: (product: Product) => void;
  onCustomizeProduct: (product: Product) => void;
  onQuickWeight: (product: Product, grams: number) => void;
  onAdjustDraftQuantity: (item: OrderItem, nextQuantity: number) => void;
  onEditDraftItem: (item: OrderItem) => void;
  onRemoveDraftItem: (item: OrderItem) => void;
  onSubmitDraft: () => void;
  onClearDraft: () => void;
  onAdvanceOrderStatus: (order: TableOrder) => void;
  onEditOrder: (order: TableOrder) => void;
  onEditOrderItem: (order: TableOrder, item: OrderItem) => void;
  onAdjustOrderItemQuantity: (order: TableOrder, item: OrderItem, nextQuantity: number) => void;
  onRemoveOrderItem: (order: TableOrder, item: OrderItem) => void;
}

export function TableDetailsModal({
  open,
  table,
  activeTab,
  onTabChange,
  isSubmittingDraft = false,
  products,
  categories,
  customers,
  onClose,
  onOpenOperations,
  onQuickAddProduct,
  onCustomizeProduct,
  onQuickWeight,
  onAdjustDraftQuantity,
  onEditDraftItem,
  onRemoveDraftItem,
  onSubmitDraft,
  onClearDraft,
  onAdvanceOrderStatus,
  onEditOrder,
  onEditOrderItem,
  onAdjustOrderItemQuantity,
  onRemoveOrderItem,
}: TableDetailsModalProps) {
  if (!table) return null;

  const customer = findCustomerById(customers, table.customerId);
  const suggestions = getTopSuggestions(table, products, customer);
  const activeOrders = getActiveOrders(table);
  const latestStatus = activeOrders[0]?.status ?? (table.draft.items.length > 0 ? "draft" : "completed");
  const draftTotal = calculateDraftTotal(table);

  return (
    <ModalShell
      open={open}
      onClose={onClose}
      title={`${table.name} Siparis Ekrani`}
      description="Garsonun 3 saniyede anlayip islem yapabilmesi icin sade ama operasyon gucu yuksek bir akış."
      size="xl"
      hideHeader
    >
      <div className="space-y-5">
        <Panel className="sticky top-0 z-20 border border-white/70 bg-white/92 p-4 backdrop-blur">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div className="flex items-center gap-3">
              <Button variant="secondary" size="lg" onClick={onClose}>
                Geri
              </Button>
              <div>
                <div className="flex flex-wrap items-center gap-3">
                  <div className="text-2xl font-semibold text-slate-950">{table.name}</div>
                  <TableStatusBadge status={table.status} />
                </div>
                <div className="mt-1 text-sm text-slate-500">
                  Son islem {formatClock(table.lastActionAt)} • Masa suresi {formatElapsedMinutes(table.openedAt)}
                </div>
              </div>
            </div>
            <Button variant="primary" size="lg" onClick={onOpenOperations}>
              Islemler
            </Button>
          </div>
        </Panel>

        <Panel className="overflow-hidden bg-gradient-to-br from-slate-950 via-slate-900 to-violet-900 p-5 text-white">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <div className="text-xs uppercase tracking-[0.22em] text-white/55">
                Masa detay ve operasyon ozeti
              </div>
              <div className="mt-4 flex flex-wrap gap-2 text-xs">
                <InfoChip label="Kisi" value={`${table.guestCount}/${table.seats}`} />
                <InfoChip label="Toplam" value={formatCurrency(calculateGrossTotal(table))} />
                <InfoChip label="Kalan" value={formatCurrency(calculateRemainingTotal(table))} />
                <InfoChip label="Aktif Fis" value={`${activeOrders.length}`} />
              </div>
            </div>
            <div className="rounded-[24px] bg-white/10 px-4 py-3 text-sm text-white/75">
              Operasyonel aksiyonlar siparis akisini bolmemek icin sag ust `Islemler` alaninda toplandi.
            </div>
          </div>
        </Panel>

        <Tabs
          value={activeTab}
          onChange={onTabChange}
          items={[
            { id: "products", label: "Urunler" },
            { id: "reservation", label: "Rezervasyon" },
            { id: "order", label: "Siparis", count: activeOrders.length + table.draft.items.length },
          ]}
        />

        {activeTab === "products" ? (
          <ProductGrid
            products={products}
            categories={categories}
            suggestions={suggestions}
            onQuickAdd={onQuickAddProduct}
            onCustomize={onCustomizeProduct}
            onQuickWeight={onQuickWeight}
          />
        ) : null}

        {activeTab === "reservation" ? (
          <div className="grid gap-4 xl:grid-cols-[1fr,1fr]">
            <Panel className="p-5">
              <div className="text-lg font-semibold text-slate-950">Rezervasyon ve musteri</div>
              {table.reservation ? (
                <div className="mt-4 rounded-[24px] border border-slate-200 bg-slate-50 p-4">
                  <div className="text-sm font-semibold text-slate-950">
                    {table.reservation.guestName}
                  </div>
                  <div className="mt-1 text-sm text-slate-500">
                    {formatShortDate(table.reservation.at)} • {table.reservation.guestCount} kisi
                  </div>
                  <div className="mt-2 text-sm text-slate-600">{table.reservation.note}</div>
                </div>
              ) : (
                <EmptyState
                  title="Rezervasyon kaydi yok"
                  description="Walk-in masalarda burasi bos kalir ama yine de okunabilir ve temiz bir alan olarak korunur."
                />
              )}

              <div className="mt-5 rounded-[24px] border border-slate-200 bg-white p-4">
                <div className="text-sm font-semibold text-slate-950">Musteri gecmisi</div>
                {customer ? (
                  <div className="mt-3 space-y-2 text-sm">
                    <div className="font-semibold text-slate-950">{customer.name}</div>
                    <div className="text-slate-500">{customer.phone}</div>
                    <div className="text-slate-500">
                      {customer.visitCount} ziyaret • Ortalama harcama {formatCurrency(customer.averageSpend)}
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {customer.notes.map((entry) => (
                        <span
                          key={entry}
                          className="rounded-full bg-violet-50 px-3 py-1 text-xs text-violet-800"
                        >
                          {entry}
                        </span>
                      ))}
                    </div>
                  </div>
                ) : (
                  <div className="mt-3 text-sm text-slate-500">
                    Bu masaya atanmis musteri bulunmuyor.
                  </div>
                )}
              </div>
            </Panel>

            <Panel className="p-5">
              <div className="text-lg font-semibold text-slate-950">Operasyon notlari</div>
              <div className="mt-4 space-y-3">
                <div className="rounded-[24px] bg-slate-50 p-4">
                  <div className="text-sm font-semibold text-slate-950">Sureli hesap</div>
                  <div className="mt-1 text-sm text-slate-500">
                    {table.timedBilling?.enabled
                      ? `${formatClock(table.timedBilling.startedAt)} baslangicli, saatlik ${formatCurrency(
                          table.timedBilling.ratePerHour,
                        )}`
                      : "Bu masa icin sureli hesap kapali."}
                  </div>
                </div>
                <div className="rounded-[24px] bg-slate-50 p-4">
                  <div className="text-sm font-semibold text-slate-950">Referans ve barkod</div>
                  <div className="mt-1 text-sm text-slate-500">
                    Kod: {table.referenceCode ?? "atanmadi"} • Barkod: {table.barcode ?? "yok"}
                  </div>
                </div>
                <div className="rounded-[24px] bg-slate-50 p-4">
                  <div className="text-sm font-semibold text-slate-950">Son islemler</div>
                  <div className="mt-3 space-y-2">
                    {table.logs.slice(0, 4).map((log) => (
                      <div key={log.id} className="text-sm text-slate-600">
                        <span className="font-medium text-slate-900">{log.title}</span> •{" "}
                        {formatClock(log.createdAt)}
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </Panel>
          </div>
        ) : null}

        {activeTab === "order" ? (
          <div className="space-y-4 pb-24">
            <Panel className="sticky top-[90px] z-10 border border-violet-100 bg-white/95 p-4 shadow-soft backdrop-blur">
              <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <div className="text-xs uppercase tracking-[0.18em] text-slate-400">
                    Siparis Taslagi Ozet
                  </div>
                  <div className="mt-2 flex flex-wrap gap-2 text-sm text-slate-600">
                    <span className="rounded-full bg-slate-100 px-3 py-1.5">
                      Taslak: <strong className="text-slate-950">{table.draft.items.length} urun</strong>
                    </span>
                    <span className="rounded-full bg-violet-50 px-3 py-1.5 text-violet-900">
                      Toplam: <strong>{formatCurrency(draftTotal)}</strong>
                    </span>
                    {isSubmittingDraft ? (
                      <span className="rounded-full bg-amber-50 px-3 py-1.5 text-amber-800">
                        Gonderiliyor...
                      </span>
                    ) : null}
                  </div>
                </div>
                <div className="text-sm text-slate-500">
                  Draft temizlenir ama aktif siparisler bu ekranda kesintisiz gorunur.
                </div>
              </div>
            </Panel>

            <div className="grid gap-4 xl:grid-cols-[320px,1fr]">
              <StatusTimeline status={latestStatus} updatedAt={table.lastActionAt} />
              <Panel className="p-5">
                <div className="text-sm font-semibold text-slate-950">
                  Hata onleyici durum ozetleri
                </div>
                <div className="mt-3 grid gap-3 md:grid-cols-3">
                  <WarnTile
                    title="Taslak"
                    description={
                      table.draft.items.length > 0
                        ? `${table.draft.items.length} kalem mutfaga gonderilmeyi bekliyor.`
                        : "Bekleyen taslak yok."
                    }
                  />
                  <WarnTile
                    title="Odeme"
                    description={`${formatCurrency(
                      calculateRemainingTotal(table),
                    )} kalan tutar bulunuyor.`}
                  />
                  <WarnTile
                    title="Servis"
                    description={
                      activeOrders.length > 0
                        ? `${activeOrders.length} aktif fis operasyon takibinde.`
                        : "Aktif fis yok."
                    }
                  />
                </div>
              </Panel>
            </div>

            <div className="grid gap-4 xl:grid-cols-[1fr,1fr]">
              <OrderDraftPanel
                table={table}
                isSubmitting={isSubmittingDraft}
                onAdjustQuantity={onAdjustDraftQuantity}
                onEditItem={onEditDraftItem}
                onRemoveItem={onRemoveDraftItem}
                onClear={onClearDraft}
              />
              <ActiveOrdersPanel
                orders={activeOrders}
                onAdvanceStatus={onAdvanceOrderStatus}
                onEditOrder={onEditOrder}
                onEditItem={onEditOrderItem}
                onAdjustItemQuantity={onAdjustOrderItemQuantity}
                onRemoveItem={onRemoveOrderItem}
              />
            </div>

            <Panel className="sticky bottom-0 z-10 border border-white/80 bg-white/96 p-4 shadow-lift backdrop-blur">
              <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div className="text-sm text-slate-500">
                  Siparis sekmesinde yalnizca siparis gonderme aksiyonu bulunur. Odeme ve diger operasyonlar `Islemler` menusundedir.
                </div>
                <Button
                  size="lg"
                  onClick={onSubmitDraft}
                  disabled={table.draft.items.length === 0 || isSubmittingDraft}
                >
                  {isSubmittingDraft ? "Siparis Gonderiliyor" : "Siparisi Gonder"}
                </Button>
              </div>
            </Panel>
          </div>
        ) : null}
      </div>
    </ModalShell>
  );
}

function InfoChip({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-full bg-white/10 px-3 py-1.5 text-white">
      <span className="text-white/70">{label}: </span>
      <span className="font-medium text-white">{value}</span>
    </div>
  );
}

function WarnTile({ title, description }: { title: string; description: string }) {
  return (
    <div className="rounded-[24px] bg-slate-50 p-4">
      <div className="text-sm font-semibold text-slate-950">{title}</div>
      <div className="mt-2 text-sm text-slate-500">{description}</div>
    </div>
  );
}
