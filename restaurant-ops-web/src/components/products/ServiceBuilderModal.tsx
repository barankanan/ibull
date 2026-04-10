"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/Button";
import { ModalShell } from "@/components/ui/ModalShell";
import { Stepper } from "@/components/ui/Stepper";
import { buildProductOrderItem } from "@/lib/restaurant";
import { OrderItem, Product, ServiceChildItem } from "@/lib/types";
import { formatCurrency, makeId } from "@/lib/utils";

const structures = [
  { id: "standard", label: "Standart", plateCount: 0 },
  { id: "1_plate", label: "1 Tabak", plateCount: 1 },
  { id: "2_plate", label: "2 Tabak", plateCount: 2 },
  { id: "3_plate", label: "3 Tabak", plateCount: 3 },
  { id: "4_plate", label: "4 Tabak", plateCount: 4 },
  { id: "5_plate", label: "5 Tabak", plateCount: 5 },
] as const;

const childModifiers = ["ekstra sos", "az tuzlu", "sogansiz", "acili", "acisiz"];

interface ServiceBuilderModalProps {
  open: boolean;
  product: Product | null;
  products: Product[];
  initialItem?: OrderItem | null;
  onClose: () => void;
  onConfirm: (item: OrderItem) => void;
}

export function ServiceBuilderModal({
  open,
  product,
  products,
  initialItem,
  onClose,
  onConfirm,
}: ServiceBuilderModalProps) {
  const [orderName, setOrderName] = useState("");
  const [structure, setStructure] = useState<(typeof structures)[number]["id"]>("standard");
  const [query, setQuery] = useState("");
  const [note, setNote] = useState("");
  const [items, setItems] = useState<ServiceChildItem[]>([]);
  const [editingChildId, setEditingChildId] = useState<string | null>(null);

  useEffect(() => {
    if (!open || !product) return;
    setOrderName(initialItem?.service?.orderName ?? product.name);
    setStructure(initialItem?.service?.structure ?? "standard");
    setNote(initialItem?.service?.note ?? "");
    setItems(initialItem?.service?.items ?? []);
    setEditingChildId(null);
    setQuery("");
  }, [initialItem, open, product]);

  if (!product) return null;

  const selectableProducts = products.filter(
    (entry) =>
      entry.kind !== "service" &&
      [entry.name, entry.description, ...(entry.tags ?? [])]
        .join(" ")
        .toLowerCase()
        .includes(query.trim().toLowerCase()),
  );

  const selectedStructure =
    structures.find((entry) => entry.id === structure) ?? structures[0];
  const plateCount = selectedStructure.plateCount;
  const total = items.reduce((sum, item) => sum + item.totalPrice, 0);

  const plateTotals =
    plateCount > 0
      ? Array.from({ length: plateCount }, (_, index) => {
          const plateNumber = index + 1;
          const price = items
            .filter((item) => item.plateNumber === plateNumber)
            .reduce((sum, item) => sum + item.totalPrice, 0);
          return { plateNumber, price };
        })
      : [];

  const addChild = (entry: Product) => {
    setItems((current) => [
      ...current,
      {
        id: makeId("service-child"),
        productId: entry.id,
        name: entry.name,
        quantity: 1,
        unitPrice: entry.price,
        totalPrice: entry.price,
        plateNumber: plateCount > 0 ? 1 : null,
        note: "",
        modifiers: [],
      },
    ]);
  };

  return (
    <ModalShell
      open={open}
      onClose={onClose}
      title={product.name}
      description="Karisik servis, tabak bazli dagitim ve otomatik fiyat hesaplama."
      size="xl"
    >
      <div className="grid gap-6 lg:grid-cols-[1.3fr,0.9fr]">
        <div className="space-y-5">
          <div className="grid gap-4 md:grid-cols-2">
            <label className="rounded-[28px] border border-slate-200 bg-white p-4">
              <div className="text-sm font-semibold text-slate-950">Servis adi</div>
              <div className="mt-2 text-sm text-slate-500">{product.name}</div>
            </label>
            <label className="rounded-[28px] border border-slate-200 bg-white p-4">
              <div className="text-sm font-semibold text-slate-950">Siparis adi</div>
              <input
                value={orderName}
                onChange={(event) => setOrderName(event.target.value)}
                className="mt-2 h-11 w-full rounded-2xl border border-slate-200 px-3 text-sm outline-none focus:border-violet-300"
              />
            </label>
          </div>

          <div className="rounded-[28px] border border-slate-200 bg-white p-4">
            <div className="text-sm font-semibold text-slate-950">Siparis yapisi secimi</div>
            <div className="mt-3 flex flex-wrap gap-2">
              {structures.map((entry) => {
                const active = entry.id === structure;
                return (
                  <button
                    key={entry.id}
                    onClick={() => setStructure(entry.id)}
                    className={`rounded-2xl px-4 py-2.5 text-sm font-medium transition ${
                      active
                        ? "bg-slate-950 text-white"
                        : "border border-slate-200 bg-slate-50 text-slate-600"
                    }`}
                  >
                    {entry.label}
                  </button>
                );
              })}
            </div>
          </div>

          <div className="rounded-[28px] border border-slate-200 bg-white p-4">
            <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
              <div>
                <div className="text-sm font-semibold text-slate-950">Servis icine urun ekle</div>
                <div className="text-sm text-slate-500">
                  Tabaga gore dagit ve aninda toplam guncellensin.
                </div>
              </div>
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Urun ara..."
                className="h-11 w-full rounded-2xl border border-slate-200 px-3 text-sm outline-none md:max-w-xs"
              />
            </div>
            <div className="mt-4 grid gap-3 md:grid-cols-2">
              {selectableProducts.map((entry) => (
                <button
                  key={entry.id}
                  onClick={() => addChild(entry)}
                  className="rounded-[24px] border border-slate-200 bg-slate-50 p-4 text-left transition hover:border-violet-200 hover:bg-violet-50"
                >
                  <div className="text-sm font-semibold text-slate-950">{entry.name}</div>
                  <div className="mt-1 text-sm text-slate-500">{entry.description}</div>
                  <div className="mt-3 text-sm font-semibold text-violet-900">
                    {formatCurrency(entry.price)}
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="space-y-5">
          <div className="rounded-[28px] border border-slate-200 bg-white p-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-sm font-semibold text-slate-950">Secili urunler</div>
                <div className="text-sm text-slate-500">
                  Hangi urunun hangi tabaga ait oldugu net gorunur.
                </div>
              </div>
              <div className="rounded-full bg-slate-950 px-3 py-1 text-xs font-medium text-white">
                {items.length} kalem
              </div>
            </div>

            <div className="mt-4 space-y-3">
              {items.length === 0 ? (
                <div className="rounded-[24px] border border-dashed border-slate-200 bg-slate-50 p-5 text-sm text-slate-500">
                  Henuz servis icine urun eklenmedi.
                </div>
              ) : null}

              {items.map((item) => {
                const editing = editingChildId === item.id;
                return (
                  <div key={item.id} className="rounded-[24px] border border-slate-200 p-4">
                    <div className="flex flex-col gap-3">
                      <div className="flex items-start justify-between gap-3">
                        <div>
                          <div className="text-sm font-semibold text-slate-950">{item.name}</div>
                          <div className="mt-1 text-xs text-slate-500">
                            {plateCount > 0
                              ? `Tabak ${item.plateNumber ?? 1}`
                              : "Standart servis"}
                          </div>
                        </div>
                        <div className="text-sm font-semibold text-slate-950">
                          {formatCurrency(item.totalPrice)}
                        </div>
                      </div>

                      <div className="flex flex-wrap items-center gap-3">
                        <Stepper
                          value={item.quantity}
                          min={1}
                          onDecrease={() =>
                            setItems((current) =>
                              current.map((entry) =>
                                entry.id === item.id
                                  ? {
                                      ...entry,
                                      quantity: Math.max(1, entry.quantity - 1),
                                      totalPrice:
                                        Math.max(1, entry.quantity - 1) * entry.unitPrice,
                                    }
                                  : entry,
                              ),
                            )
                          }
                          onIncrease={() =>
                            setItems((current) =>
                              current.map((entry) =>
                                entry.id === item.id
                                  ? {
                                      ...entry,
                                      quantity: entry.quantity + 1,
                                      totalPrice: (entry.quantity + 1) * entry.unitPrice,
                                    }
                                  : entry,
                              ),
                            )
                          }
                        />
                        {plateCount > 0 ? (
                          <select
                            value={item.plateNumber ?? 1}
                            onChange={(event) =>
                              setItems((current) =>
                                current.map((entry) =>
                                  entry.id === item.id
                                    ? {
                                        ...entry,
                                        plateNumber: Number(event.target.value),
                                      }
                                    : entry,
                                ),
                              )
                            }
                            className="h-11 rounded-2xl border border-slate-200 px-3 text-sm"
                          >
                            {Array.from({ length: plateCount }, (_, index) => (
                              <option key={index + 1} value={index + 1}>
                                Tabak {index + 1}
                              </option>
                            ))}
                          </select>
                        ) : null}
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={() =>
                            setEditingChildId((current) =>
                              current === item.id ? null : item.id,
                            )
                          }
                        >
                          Ozellestir
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() =>
                            setItems((current) =>
                              current.filter((entry) => entry.id !== item.id),
                            )
                          }
                        >
                          Sil
                        </Button>
                      </div>

                      {editing ? (
                        <div className="rounded-[20px] bg-slate-50 p-3">
                          <div className="mb-2 text-xs font-semibold uppercase tracking-[0.16em] text-slate-400">
                            Ozellestirme
                          </div>
                          <div className="flex flex-wrap gap-2">
                            {childModifiers.map((modifier) => {
                              const active = item.modifiers.includes(modifier);
                              return (
                                <button
                                  key={modifier}
                                  onClick={() =>
                                    setItems((current) =>
                                      current.map((entry) =>
                                        entry.id === item.id
                                          ? {
                                              ...entry,
                                              modifiers: active
                                                ? entry.modifiers.filter((value) => value !== modifier)
                                                : [...entry.modifiers, modifier],
                                            }
                                          : entry,
                                      ),
                                    )
                                  }
                                  className={`rounded-full px-3 py-2 text-xs ${
                                    active
                                      ? "bg-violet-100 text-violet-900"
                                      : "border border-slate-200 bg-white text-slate-600"
                                  }`}
                                >
                                  {modifier}
                                </button>
                              );
                            })}
                          </div>
                          <textarea
                            value={item.note}
                            onChange={(event) =>
                              setItems((current) =>
                                current.map((entry) =>
                                  entry.id === item.id
                                    ? {
                                        ...entry,
                                        note: event.target.value,
                                      }
                                    : entry,
                                ),
                              )
                            }
                            rows={2}
                            placeholder="Bu urune not..."
                            className="mt-3 w-full rounded-2xl border border-slate-200 px-3 py-2 text-sm"
                          />
                        </div>
                      ) : null}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="rounded-[28px] border border-slate-200 bg-white p-4">
            <div className="text-sm font-semibold text-slate-950">Tabak bazli fiyat ozeti</div>
            <div className="mt-4 space-y-2">
              {plateTotals.length > 0 ? (
                plateTotals.map((entry) => (
                  <div
                    key={entry.plateNumber}
                    className="flex items-center justify-between rounded-2xl bg-slate-50 px-3 py-3 text-sm"
                  >
                    <span>Tabak {entry.plateNumber}</span>
                    <span className="font-semibold text-slate-950">
                      {formatCurrency(entry.price)}
                    </span>
                  </div>
                ))
              ) : (
                <div className="rounded-2xl bg-slate-50 px-3 py-3 text-sm text-slate-500">
                  Standart yapida toplam fiyat genel olarak hesaplanir.
                </div>
              )}
            </div>
            <label className="mt-4 block">
              <div className="mb-2 text-sm font-semibold text-slate-950">Genel not</div>
              <textarea
                value={note}
                onChange={(event) => setNote(event.target.value)}
                rows={3}
                placeholder="Servis icin genel not..."
                className="w-full rounded-[20px] border border-slate-200 px-3 py-3 text-sm"
              />
            </label>

            <div className="mt-5 rounded-[24px] bg-slate-950 px-4 py-4 text-white">
              <div className="text-xs uppercase tracking-[0.18em] text-white/60">
                Genel toplam
              </div>
              <div className="mt-1 text-2xl font-semibold">{formatCurrency(total)}</div>
            </div>

            <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:justify-end">
              <Button variant="secondary" onClick={onClose}>
                Vazgec
              </Button>
              <Button
                onClick={() =>
                  onConfirm(
                    buildProductOrderItem(product, {
                      id: initialItem?.id,
                      name: orderName || product.name,
                      kind: "service",
                      quantity: 1,
                      createdAt: initialItem?.createdAt,
                      status: initialItem?.status ?? "draft",
                      customizations: {
                        note,
                        modifiers: [],
                      },
                      service: {
                        serviceName: product.name,
                        orderName: orderName || product.name,
                        structure,
                        plateCount,
                        note,
                        items,
                      },
                    }),
                  )
                }
                disabled={items.length === 0}
              >
                Siparise Ekle
              </Button>
            </div>
          </div>
        </div>
      </div>
    </ModalShell>
  );
}
