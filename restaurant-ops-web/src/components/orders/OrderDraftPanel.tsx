import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Panel } from "@/components/ui/Panel";
import { Stepper } from "@/components/ui/Stepper";
import { OrderItem, RestaurantTable } from "@/lib/types";

interface OrderDraftPanelProps {
  table: RestaurantTable;
  isSubmitting?: boolean;
  onAdjustQuantity: (item: OrderItem, nextQuantity: number) => void;
  onEditItem: (item: OrderItem) => void;
  onRemoveItem: (item: OrderItem) => void;
  onClear: () => void;
}

export function OrderDraftPanel({
  table,
  isSubmitting = false,
  onAdjustQuantity,
  onEditItem,
  onRemoveItem,
  onClear,
}: OrderDraftPanelProps) {
  return (
    <Panel className="p-4">
      <div className="flex items-center justify-between gap-3">
        <div>
          <div className="text-lg font-semibold text-slate-950">Yeni Siparis Taslagi</div>
          <div className="text-sm text-slate-500">
            {table.draft.editingOrderId
              ? "Var olan siparisi guncelleme modundasin."
              : "Mutfaga gitmeden once son kontrol alani."}
          </div>
        </div>
        <Button
          variant="ghost"
          size="sm"
          onClick={onClear}
          disabled={table.draft.items.length === 0 || isSubmitting}
        >
          Taslagi Temizle
        </Button>
      </div>

      {table.draft.items.length === 0 ? (
        <div className="mt-4">
          <EmptyState
            title="Yeni siparis taslagi bos"
            description="Urunler sekmesinden tek tikla urun ekleyebilir, gramajli veya servis urunleri detayli sekilde hazirlayabilirsin."
          />
        </div>
      ) : (
        <div className="mt-4 space-y-3">
          {table.draft.items.map((item) => (
            <div key={item.id} className="rounded-[24px] border border-slate-200 p-4">
              <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                <div>
                  <div className="text-sm font-semibold text-slate-950">{item.name}</div>
                  <div className="mt-1 text-sm text-slate-500">
                    {item.kind === "service"
                      ? `${item.service?.items.length ?? 0} alt urun`
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
                      disabled={isSubmitting}
                      onDecrease={() => onAdjustQuantity(item, Math.max(1, item.quantity - 1))}
                      onIncrease={() => onAdjustQuantity(item, item.quantity + 1)}
                    />
                  ) : null}
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => onEditItem(item)}
                    disabled={isSubmitting}
                  >
                    Duzenle
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => onRemoveItem(item)}
                    disabled={isSubmitting}
                  >
                    Sil
                  </Button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </Panel>
  );
}
