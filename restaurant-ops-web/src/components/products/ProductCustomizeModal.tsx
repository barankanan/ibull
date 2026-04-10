"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/Button";
import { ModalShell } from "@/components/ui/ModalShell";
import { Stepper } from "@/components/ui/Stepper";
import { buildProductOrderItem } from "@/lib/restaurant";
import { OrderItem, Product } from "@/lib/types";

const quickModifiers = [
  "ekstra sos",
  "bol peynirli",
  "az tuzlu",
  "domatessiz",
  "sogansiz",
  "acili",
  "az acili",
  "acisiz",
];

interface ProductCustomizeModalProps {
  open: boolean;
  product: Product | null;
  initialItem?: OrderItem | null;
  onClose: () => void;
  onConfirm: (item: OrderItem) => void;
}

export function ProductCustomizeModal({
  open,
  product,
  initialItem,
  onClose,
  onConfirm,
}: ProductCustomizeModalProps) {
  const [quantity, setQuantity] = useState(1);
  const [grams, setGrams] = useState(500);
  const [note, setNote] = useState("");
  const [modifiers, setModifiers] = useState<string[]>([]);

  useEffect(() => {
    if (!open || !product) return;
    setQuantity(initialItem?.quantity ?? 1);
    setGrams(initialItem?.customizations.grams ?? product.quickWeightOptions?.[1] ?? 500);
    setNote(initialItem?.customizations.note ?? "");
    setModifiers(initialItem?.customizations.modifiers ?? []);
  }, [initialItem, open, product]);

  if (!product) return null;

  const toggleModifier = (value: string) => {
    setModifiers((current) =>
      current.includes(value)
        ? current.filter((item) => item !== value)
        : [...current, value],
    );
  };

  return (
    <ModalShell
      open={open}
      onClose={onClose}
      title={product.name}
      description="Hizli ve hatasiz ozellestirme akisi."
      size="md"
    >
      <div className="grid gap-5">
        <div className="grid gap-4 md:grid-cols-2">
          <div className="rounded-[28px] border border-slate-200 bg-slate-50 p-4">
            <div className="text-sm text-slate-500">Adet</div>
            <div className="mt-3">
              <Stepper
                value={quantity}
                min={1}
                onDecrease={() => setQuantity((current) => Math.max(1, current - 1))}
                onIncrease={() => setQuantity((current) => current + 1)}
              />
            </div>
          </div>

          <div className="rounded-[28px] border border-slate-200 bg-slate-50 p-4">
            <div className="text-sm text-slate-500">Fiyat</div>
            <div className="mt-3 text-2xl font-semibold text-slate-950">
              {product.kind === "service" ? "Dinamik" : `${product.price} TL`}
            </div>
          </div>
        </div>

        {product.kind === "weighted" ? (
          <div>
            <div className="mb-3 text-sm font-semibold text-slate-950">Gramaj</div>
            <div className="flex flex-wrap gap-2">
              {(product.quickWeightOptions ?? [250, 500, 750]).map((option) => (
                <button
                  key={option}
                  onClick={() => setGrams(option)}
                  className={`rounded-2xl px-4 py-2.5 text-sm font-medium transition ${
                    grams === option
                      ? "bg-violet-600 text-white"
                      : "border border-slate-200 bg-white text-slate-600"
                  }`}
                >
                  {option}g
                </button>
              ))}
            </div>
          </div>
        ) : null}

        <div>
          <div className="mb-3 text-sm font-semibold text-slate-950">Hizli ozellikler</div>
          <div className="flex flex-wrap gap-2">
            {quickModifiers.map((modifier) => {
              const active = modifiers.includes(modifier);
              return (
                <button
                  key={modifier}
                  onClick={() => toggleModifier(modifier)}
                  className={`rounded-full px-4 py-2 text-sm transition ${
                    active
                      ? "bg-violet-100 text-violet-900 ring-1 ring-violet-200"
                      : "border border-slate-200 bg-white text-slate-600"
                  }`}
                >
                  {modifier}
                </button>
              );
            })}
          </div>
        </div>

        <div>
          <div className="mb-3 text-sm font-semibold text-slate-950">Aciklama / not</div>
          <textarea
            value={note}
            onChange={(event) => setNote(event.target.value)}
            rows={4}
            placeholder="Mutfak veya servis notu..."
            className="w-full rounded-[24px] border border-slate-200 bg-white px-4 py-3 text-sm outline-none transition focus:border-violet-300"
          />
        </div>

        <div className="flex flex-col gap-3 sm:flex-row sm:justify-end">
          <Button variant="secondary" onClick={onClose}>
            Vazgec
          </Button>
          <Button
            onClick={() => {
              onConfirm(
                buildProductOrderItem(product, {
                  id: initialItem?.id,
                  quantity,
                  createdAt: initialItem?.createdAt,
                  status: initialItem?.status ?? "draft",
                  customizations: {
                    note,
                    modifiers,
                    grams: product.kind === "weighted" ? grams : undefined,
                  },
                }),
              );
            }}
          >
            Onayla
          </Button>
        </div>
      </div>
    </ModalShell>
  );
}
