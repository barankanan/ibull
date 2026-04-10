"use client";

import { useState } from "react";
import { EmptyState } from "@/components/ui/EmptyState";
import { Panel } from "@/components/ui/Panel";
import { ProductCard } from "@/components/products/ProductCard";
import { Product, ProductCategory } from "@/lib/types";
import { cn } from "@/lib/utils";

interface ProductGridProps {
  products: Product[];
  categories: ProductCategory[];
  suggestions: Product[];
  onQuickAdd: (product: Product) => void;
  onCustomize: (product: Product) => void;
  onQuickWeight: (product: Product, grams: number) => void;
}

export function ProductGrid({
  products,
  categories,
  suggestions,
  onQuickAdd,
  onCustomize,
  onQuickWeight,
}: ProductGridProps) {
  const [categoryId, setCategoryId] = useState<string>("all");
  const [query, setQuery] = useState("");

  const filtered = products.filter((product) => {
    const matchesCategory = categoryId === "all" || product.categoryId === categoryId;
    const normalized = query.trim().toLowerCase();
    const matchesQuery =
      normalized.length === 0 ||
      [product.name, product.description, ...(product.tags ?? [])]
        .join(" ")
        .toLowerCase()
        .includes(normalized);
    return matchesCategory && matchesQuery;
  });

  return (
    <div className="space-y-5">
      <Panel className="p-4">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <div className="text-lg font-semibold text-slate-950">
              Hizli urun secimi
            </div>
            <div className="mt-1 text-sm text-slate-500">
              En az tik ile urun ekleme ve detayli ozellestirme.
            </div>
          </div>
          <label className="relative block w-full lg:max-w-sm">
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Urun ara, kategori veya etiket yaz..."
              className="h-12 w-full rounded-2xl border border-slate-200 bg-white px-4 text-sm outline-none transition focus:border-violet-300"
            />
          </label>
        </div>

        <div className="mt-4 flex flex-wrap gap-2">
          <CategoryChip
            label="Tum urunler"
            active={categoryId === "all"}
            onClick={() => setCategoryId("all")}
          />
          {categories.map((category) => (
            <CategoryChip
              key={category.id}
              label={category.name}
              active={category.id === categoryId}
              onClick={() => setCategoryId(category.id)}
            />
          ))}
        </div>
      </Panel>

      {suggestions.length > 0 ? (
        <Panel className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-sm font-semibold text-slate-950">Hizli oneriler</div>
              <div className="text-sm text-slate-500">
                Musteri gecmisi ve satis hizina gore onceliklendirildi.
              </div>
            </div>
          </div>
          <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            {suggestions.map((product) => (
              <button
                key={product.id}
                onClick={() => onQuickAdd(product)}
                className="rounded-[24px] border border-violet-100 bg-violet-50 px-4 py-4 text-left transition hover:border-violet-300 hover:bg-violet-100"
              >
                <div className="text-sm font-semibold text-violet-950">{product.name}</div>
                <div className="mt-1 text-sm text-violet-700">{product.description}</div>
              </button>
            ))}
          </div>
        </Panel>
      ) : null}

      {filtered.length === 0 ? (
        <EmptyState
          title="Bu filtrede urun bulunamadi"
          description="Garsonun 3 saniyede karar verebilmesi icin filtreyi sade tuttuk. Farkli bir kategori sec veya arama ifadesini temizle."
        />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {filtered.map((product) => (
            <ProductCard
              key={product.id}
              product={product}
              onQuickAdd={() => onQuickAdd(product)}
              onCustomize={() => onCustomize(product)}
              onQuickWeight={(grams) => onQuickWeight(product, grams)}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function CategoryChip({
  label,
  active,
  onClick,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "rounded-2xl px-4 py-2.5 text-sm font-medium transition",
        active
          ? "bg-slate-950 text-white"
          : "border border-slate-200 bg-white text-slate-600 hover:border-violet-200 hover:text-violet-700",
      )}
    >
      {label}
    </button>
  );
}
