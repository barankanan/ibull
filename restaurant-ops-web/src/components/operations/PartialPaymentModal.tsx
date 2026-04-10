"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/Button";
import { ModalShell } from "@/components/ui/ModalShell";
import { Panel } from "@/components/ui/Panel";
import { calculateRemainingTotal } from "@/lib/restaurant";
import { PaymentMethod, RestaurantTable } from "@/lib/types";
import { formatClock, formatCurrency } from "@/lib/utils";

const methods: Array<{ id: PaymentMethod; label: string }> = [
  { id: "cash", label: "Nakit" },
  { id: "card", label: "Kart" },
  { id: "meal_card", label: "Yemek Karti" },
  { id: "qr", label: "QR" },
  { id: "voucher", label: "Kupon" },
];

interface PartialPaymentModalProps {
  open: boolean;
  table: RestaurantTable | null;
  onClose: () => void;
  onSubmit: (amount: number, method: PaymentMethod, note: string) => void;
}

export function PartialPaymentModal({
  open,
  table,
  onClose,
  onSubmit,
}: PartialPaymentModalProps) {
  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState<PaymentMethod>("cash");
  const [note, setNote] = useState("");

  useEffect(() => {
    if (!open || !table) return;
    setAmount(String(calculateRemainingTotal(table)));
    setMethod("cash");
    setNote("");
  }, [open, table]);

  if (!table) return null;

  const remaining = calculateRemainingTotal(table);

  return (
    <ModalShell
      open={open}
      onClose={onClose}
      title="Ara Odeme Al"
      description={`${table.name} icin kismi odeme al, kalan tutari aninda guncelle.`}
      size="md"
    >
      <div className="grid gap-4">
        <Panel className="p-4">
          <div className="text-sm text-slate-500">Kalan tutar</div>
          <div className="mt-2 text-3xl font-semibold text-slate-950">
            {formatCurrency(remaining)}
          </div>
        </Panel>

        <label className="block">
          <div className="mb-2 text-sm font-semibold text-slate-950">Ara odeme miktari</div>
          <input
            value={amount}
            onChange={(event) => setAmount(event.target.value)}
            type="number"
            min="0"
            step="0.01"
            className="h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm outline-none focus:border-violet-300"
          />
        </label>

        <div>
          <div className="mb-2 text-sm font-semibold text-slate-950">Odeme tipi</div>
          <div className="flex flex-wrap gap-2">
            {methods.map((entry) => {
              const active = entry.id === method;
              return (
                <button
                  key={entry.id}
                  onClick={() => setMethod(entry.id)}
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

        <label className="block">
          <div className="mb-2 text-sm font-semibold text-slate-950">Not</div>
          <textarea
            rows={3}
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder="Odeme aciklamasi..."
            className="w-full rounded-[24px] border border-slate-200 px-4 py-3 text-sm outline-none focus:border-violet-300"
          />
        </label>

        <Panel className="p-4">
          <div className="text-sm font-semibold text-slate-950">Gecmis ara odemeler</div>
          <div className="mt-3 space-y-2">
            {table.payments.length === 0 ? (
              <div className="text-sm text-slate-500">Bu masa icin kayitli ara odeme yok.</div>
            ) : (
              table.payments.map((payment) => (
                <div
                  key={payment.id}
                  className="flex items-center justify-between rounded-2xl bg-slate-50 px-3 py-3 text-sm"
                >
                  <div>
                    <div className="font-medium text-slate-950">{payment.note ?? "Odeme"}</div>
                    <div className="text-slate-500">{formatClock(payment.createdAt)}</div>
                  </div>
                  <div className="font-semibold text-slate-950">
                    {formatCurrency(payment.amount)}
                  </div>
                </div>
              ))
            )}
          </div>
        </Panel>

        <div className="flex flex-col gap-3 sm:flex-row sm:justify-end">
          <Button variant="secondary" onClick={onClose}>
            Vazgec
          </Button>
          <Button
            onClick={() => onSubmit(Number(amount || 0), method, note)}
            disabled={Number(amount || 0) <= 0 || Number(amount || 0) > remaining}
          >
            Ara Odemeyi Kaydet
          </Button>
        </div>
      </div>
    </ModalShell>
  );
}
