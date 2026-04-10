"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/Button";
import { ModalShell } from "@/components/ui/ModalShell";
import { Panel } from "@/components/ui/Panel";
import { calculateRemainingTotal, getActiveOrders } from "@/lib/restaurant";
import { BillSplitPlan, RestaurantTable, SplitMode } from "@/lib/types";
import { formatCurrency, makeId, roundCurrency } from "@/lib/utils";

interface SplitBillModalProps {
  open: boolean;
  table: RestaurantTable | null;
  onClose: () => void;
  onCreatePlan: (plan: BillSplitPlan) => void;
}

export function SplitBillModal({
  open,
  table,
  onClose,
  onCreatePlan,
}: SplitBillModalProps) {
  const [mode, setMode] = useState<SplitMode>("product");
  const [productAssignments, setProductAssignments] = useState<Record<string, 0 | 1>>({});
  const [personCount, setPersonCount] = useState(2);
  const [primaryAmount, setPrimaryAmount] = useState("");

  useEffect(() => {
    if (!open || !table) return;
    const nextAssignments: Record<string, 0 | 1> = {};
    getActiveOrders(table).forEach((order) => {
      order.items.forEach((item, index) => {
        nextAssignments[item.id] = index % 2 === 0 ? 0 : 1;
      });
    });
    setProductAssignments(nextAssignments);
    setPersonCount(Math.max(2, table.guestCount || 2));
    setPrimaryAmount(String(roundCurrency(calculateRemainingTotal(table) / 2)));
    setMode("product");
  }, [open, table]);

  if (!table) return null;

  const lines = getActiveOrders(table).flatMap((order) =>
    order.items.map((item) => ({
      id: item.id,
      label: `${order.label} • ${item.name}`,
      amount: item.totalPrice,
    })),
  );

  const total = calculateRemainingTotal(table);

  let previewParts: BillSplitPlan["parts"] = [];

  if (mode === "product") {
    previewParts = [
      {
        id: "bill-a",
        label: "Hesap A",
        amount: roundCurrency(
          lines
            .filter((line) => productAssignments[line.id] === 0)
            .reduce((sum, line) => sum + line.amount, 0),
        ),
        lineItemIds: lines.filter((line) => productAssignments[line.id] === 0).map((line) => line.id),
      },
      {
        id: "bill-b",
        label: "Hesap B",
        amount: roundCurrency(
          lines
            .filter((line) => productAssignments[line.id] !== 0)
            .reduce((sum, line) => sum + line.amount, 0),
        ),
        lineItemIds: lines.filter((line) => productAssignments[line.id] !== 0).map((line) => line.id),
      },
    ];
  } else if (mode === "person") {
    const base = roundCurrency(total / personCount);
    previewParts = Array.from({ length: personCount }, (_, index) => ({
      id: `guest-${index + 1}`,
      label: `Kisi ${index + 1}`,
      amount: index === 0 ? roundCurrency(total - base * (personCount - 1)) : base,
      lineItemIds: [],
    }));
  } else {
    const first = Number(primaryAmount || 0);
    const second = Math.max(0, roundCurrency(total - first));
    previewParts = [
      { id: "amount-a", label: "Parca A", amount: first, lineItemIds: [] },
      { id: "amount-b", label: "Parca B", amount: second, lineItemIds: [] },
    ];
  }

  return (
    <ModalShell
      open={open}
      onClose={onClose}
      title="Hesabi Bol"
      description="Urun bazli, kisi bazli veya tutar bazli ayri odeme plani olustur."
      size="lg"
    >
      <div className="grid gap-5 lg:grid-cols-[1.15fr,0.85fr]">
        <div className="space-y-4">
          <Panel className="p-4">
            <div className="text-sm font-semibold text-slate-950">Bolme yontemi</div>
            <div className="mt-3 flex flex-wrap gap-2">
              {[
                { id: "product", label: "Urun Bazli" },
                { id: "person", label: "Kisi Bazli" },
                { id: "amount", label: "Tutar Bazli" },
              ].map((entry) => {
                const active = entry.id === mode;
                return (
                  <button
                    key={entry.id}
                    onClick={() => setMode(entry.id as SplitMode)}
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
          </Panel>

          {mode === "product" ? (
            <Panel className="p-4">
              <div className="text-sm font-semibold text-slate-950">Urun bazli secim</div>
              <div className="mt-3 space-y-3">
                {lines.map((line) => (
                  <div
                    key={line.id}
                    className="flex flex-col gap-2 rounded-[22px] border border-slate-200 p-4 md:flex-row md:items-center md:justify-between"
                  >
                    <div>
                      <div className="text-sm font-semibold text-slate-950">{line.label}</div>
                      <div className="text-sm text-slate-500">{formatCurrency(line.amount)}</div>
                    </div>
                    <div className="flex gap-2">
                      {["Hesap A", "Hesap B"].map((label, index) => {
                        const active = productAssignments[line.id] === index;
                        return (
                          <button
                            key={label}
                            onClick={() =>
                              setProductAssignments((current) => ({
                                ...current,
                                [line.id]: index as 0 | 1,
                              }))
                            }
                            className={`rounded-2xl px-4 py-2 text-sm ${
                              active
                                ? "bg-violet-600 text-white"
                                : "border border-slate-200 bg-white text-slate-600"
                            }`}
                          >
                            {label}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                ))}
              </div>
            </Panel>
          ) : null}

          {mode === "person" ? (
            <Panel className="p-4">
              <div className="text-sm font-semibold text-slate-950">Kisi sayisi</div>
              <input
                value={personCount}
                onChange={(event) => setPersonCount(Math.max(2, Number(event.target.value || 2)))}
                type="number"
                min="2"
                max="8"
                className="mt-3 h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm outline-none focus:border-violet-300"
              />
            </Panel>
          ) : null}

          {mode === "amount" ? (
            <Panel className="p-4">
              <div className="text-sm font-semibold text-slate-950">Ilk parcaya yazilacak tutar</div>
              <input
                value={primaryAmount}
                onChange={(event) => setPrimaryAmount(event.target.value)}
                type="number"
                min="0"
                max={total}
                step="0.01"
                className="mt-3 h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm outline-none focus:border-violet-300"
              />
            </Panel>
          ) : null}
        </div>

        <Panel className="p-4">
          <div className="text-sm font-semibold text-slate-950">Olusacak odeme plani</div>
          <div className="mt-4 space-y-3">
            {previewParts.map((part) => (
              <div key={part.id} className="rounded-[22px] bg-slate-50 p-4">
                <div className="text-sm text-slate-500">{part.label}</div>
                <div className="mt-1 text-xl font-semibold text-slate-950">
                  {formatCurrency(part.amount)}
                </div>
              </div>
            ))}
          </div>
          <div className="mt-5 text-sm text-slate-500">
            Toplam: <span className="font-semibold text-slate-950">{formatCurrency(total)}</span>
          </div>
          <div className="mt-5 flex flex-col gap-3">
            <Button
              onClick={() =>
                onCreatePlan({
                  id: makeId("split"),
                  createdAt: new Date().toISOString(),
                  mode,
                  parts: previewParts,
                  note: `${mode} bazli odeme plani`,
                })
              }
              disabled={
                previewParts.length < 2 ||
                previewParts.some((part) => part.amount <= 0) ||
                roundCurrency(previewParts.reduce((sum, part) => sum + part.amount, 0)) !==
                  roundCurrency(total)
              }
            >
              Odeme Planini Uret
            </Button>
            <Button variant="secondary" onClick={onClose}>
              Kapat
            </Button>
          </div>
        </Panel>
      </div>
    </ModalShell>
  );
}
