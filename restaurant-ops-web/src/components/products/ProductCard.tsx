import { Button } from "@/components/ui/Button";
import { Panel } from "@/components/ui/Panel";
import {
  PRODUCT_TONE_CLASS,
  STOCK_META,
} from "@/lib/restaurant";
import { Product } from "@/lib/types";
import { cn, formatCurrency } from "@/lib/utils";

interface ProductCardProps {
  product: Product;
  onQuickAdd: () => void;
  onCustomize: () => void;
  onQuickWeight?: (grams: number) => void;
}

export function ProductCard({
  product,
  onQuickAdd,
  onCustomize,
  onQuickWeight,
}: ProductCardProps) {
  const isService = product.kind === "service";
  const isWeighted = product.kind === "weighted";

  return (
    <Panel className="overflow-hidden p-0">
      <div
        className={cn(
          "relative h-36 bg-gradient-to-br p-4 text-white",
          PRODUCT_TONE_CLASS[product.visualTone],
        )}
      >
        <div className="flex items-start justify-between gap-3">
          <div className="rounded-full bg-white/20 px-3 py-1 text-xs font-medium backdrop-blur">
            {product.kind === "service"
              ? "Servis"
              : product.kind === "weighted"
                ? "Gramajli"
                : "Standart"}
          </div>
          <span className={cn("rounded-full px-3 py-1 text-xs", STOCK_META[product.stockState])}>
            {product.stockLabel}
          </span>
        </div>
        <div className="absolute bottom-4 left-4 right-4">
          <div className="text-lg font-semibold">{product.name}</div>
          <div className="mt-1 text-sm text-white/80">{product.description}</div>
        </div>
      </div>

      <div className="space-y-4 p-4">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-xs uppercase tracking-[0.18em] text-slate-400">
              Fiyat
            </div>
            <div className="mt-1 text-xl font-semibold text-slate-950">
              {isService ? "Dinamik" : formatCurrency(product.price)}
            </div>
          </div>
          <div className="text-right text-xs text-slate-500">
            Hazirlama
            <div className="mt-1 text-sm font-semibold text-slate-950">
              {product.prepMinutes} dk
            </div>
          </div>
        </div>

        {isWeighted && product.quickWeightOptions?.length ? (
          <div className="flex flex-wrap gap-2">
            {product.quickWeightOptions.map((grams) => (
              <button
                key={grams}
                onClick={() => onQuickWeight?.(grams)}
                className="rounded-2xl border border-violet-200 bg-violet-50 px-3 py-2 text-xs font-medium text-violet-900 transition hover:bg-violet-100"
              >
                +{grams}g
              </button>
            ))}
          </div>
        ) : null}

        <div className="flex gap-2">
          <Button variant={isService ? "soft" : "primary"} fullWidth onClick={onQuickAdd}>
            {isService ? "Servisi Olustur" : "Hizli Ekle"}
          </Button>
          <Button variant="secondary" fullWidth onClick={onCustomize}>
            Ozellestir
          </Button>
        </div>
      </div>
    </Panel>
  );
}
