import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Panel } from "@/components/ui/Panel";
import { Stepper } from "@/components/ui/Stepper";
import { TableStatusBadge } from "@/components/tables/TableStatusBadge";
import { OrderItem, TableOrder } from "@/lib/types";
import { formatClock, formatCurrency } from "@/lib/utils";

interface ActiveOrdersPanelProps {
  orders: TableOrder[];
  onAdvanceStatus: (order: TableOrder) => void;
  onEditOrder: (order: TableOrder) => void;
  onEditItem: (order: TableOrder, item: OrderItem) => void;
  onAdjustItemQuantity: (order: TableOrder, item: OrderItem, nextQuantity: number) => void;
  onRemoveItem: (order: TableOrder, item: OrderItem) => void;
}

export function ActiveOrdersPanel({
  orders,
  onAdvanceStatus,
  onEditOrder,
  onEditItem,
  onAdjustItemQuantity,
  onRemoveItem,
}: ActiveOrdersPanelProps) {
  if (orders.length === 0) {
    return (
      <EmptyState
        title="Masaya dusen aktif siparis yok"
        description="Yeni siparis gonderildiginde veya musteri QR siparisi geldiginde bu panel otomatik dolar."
      />
    );
  }

  return (
    <div className="space-y-4">
      {orders.map((order) => (
        <Panel key={order.id} className="p-4">
          <div className="flex flex-col gap-4">
            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <div className="flex flex-wrap items-center gap-3">
                  <div className="text-lg font-semibold text-slate-950">{order.label}</div>
                  <TableStatusBadge status={order.status} />
                </div>
                <div className="mt-1 text-sm text-slate-500">
                  Son guncelleme {formatClock(order.updatedAt)}
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                <Button variant="secondary" size="sm" onClick={() => onEditOrder(order)}>
                  Taslaga Al
                </Button>
                <Button variant="soft" size="sm" onClick={() => onAdvanceStatus(order)}>
                  Durumu Ilerle
                </Button>
              </div>
            </div>

            <div className="space-y-3">
              {order.items.map((item) => (
                <div
                  key={item.id}
                  className="rounded-[22px] border border-slate-200 bg-slate-50 p-4"
                >
                  <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                    <div>
                      <div className="text-sm font-semibold text-slate-950">{item.name}</div>
                      <div className="mt-1 text-sm text-slate-500">
                        {item.kind === "service"
                          ? `${item.service?.items.length ?? 0} alt kalem`
                          : item.customizations.grams
                            ? `${item.customizations.grams}g`
                            : "Standart porsiyon"}
                      </div>
                      {item.customizations.modifiers.length > 0 || item.customizations.note ? (
                        <div className="mt-2 text-xs text-slate-500">
                          {[...item.customizations.modifiers, item.customizations.note]
                            .filter(Boolean)
                            .join(" • ")}
                        </div>
                      ) : null}
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                      {item.kind !== "service" ? (
                        <Stepper
                          value={item.quantity}
                          min={1}
                          onDecrease={() =>
                            onAdjustItemQuantity(order, item, Math.max(1, item.quantity - 1))
                          }
                          onIncrease={() => onAdjustItemQuantity(order, item, item.quantity + 1)}
                        />
                      ) : null}
                      <Button variant="secondary" size="sm" onClick={() => onEditItem(order, item)}>
                        Duzenle
                      </Button>
                      <Button variant="ghost" size="sm" onClick={() => onRemoveItem(order, item)}>
                        Sil
                      </Button>
                      <div className="min-w-[110px] text-right text-sm font-semibold text-slate-950">
                        {formatCurrency(item.totalPrice)}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="flex items-center justify-between rounded-[22px] bg-white px-4 py-3">
              <span className="text-sm text-slate-500">Siparis Toplami</span>
              <span className="text-lg font-semibold text-slate-950">
                {formatCurrency(order.totalPrice)}
              </span>
            </div>
          </div>
        </Panel>
      ))}
    </div>
  );
}
