"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/Button";
import { ModalShell } from "@/components/ui/ModalShell";
import { Panel } from "@/components/ui/Panel";
import {
  applyTransferModeLabel,
  calculateGrossTotal,
  getActiveOrders,
} from "@/lib/restaurant";
import { RestaurantTable, TransferMode } from "@/lib/types";
import { cn, formatCurrency } from "@/lib/utils";

interface TransferTableModalProps {
  open: boolean;
  sourceTable: RestaurantTable | null;
  tables: RestaurantTable[];
  onClose: () => void;
  onConfirm: (targetTableId: string, mode: TransferMode) => void;
}

export function TransferTableModal({
  open,
  sourceTable,
  tables,
  onClose,
  onConfirm,
}: TransferTableModalProps) {
  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [targetTableId, setTargetTableId] = useState<string>("");
  const [mode, setMode] = useState<TransferMode>("all");

  useEffect(() => {
    if (!open) return;
    setStep(1);
    setTargetTableId("");
    setMode("all");
  }, [open]);

  if (!sourceTable) return null;

  const candidateTables = tables.filter((table) => table.id !== sourceTable.id);
  const target = candidateTables.find((table) => table.id === targetTableId) ?? null;
  const targetOccupied = !!target && (target.orders.length > 0 || target.draft.items.length > 0);
  const availableModes: TransferMode[] = targetOccupied
    ? ["merge", "draft-only"]
    : ["all", "draft-only"];

  return (
    <ModalShell
      open={open}
      onClose={onClose}
      title="Masa Aktar"
      description="Veri kaybi olmadan hedef masaya taslak ve aktif siparis aktar."
      size="lg"
    >
      <div className="space-y-5">
        <Panel className="p-4">
          <div className="grid gap-3 md:grid-cols-4">
            <TransferMetric label="Kaynak masa" value={sourceTable.name} />
            <TransferMetric label="Toplam" value={formatCurrency(calculateGrossTotal(sourceTable))} />
            <TransferMetric label="Taslak" value={`${sourceTable.draft.items.length} kalem`} />
            <TransferMetric
              label="Aktif siparis"
              value={`${getActiveOrders(sourceTable).length} fis`}
            />
          </div>
        </Panel>

        {step === 1 ? (
          <div className="grid gap-3 md:grid-cols-2">
            {candidateTables.map((table) => {
              const occupied = table.orders.length > 0 || table.draft.items.length > 0;
              return (
                <button
                  key={table.id}
                  onClick={() => {
                    setTargetTableId(table.id);
                    setStep(2);
                  }}
                  className={cn(
                    "rounded-[28px] border p-4 text-left transition",
                    occupied
                      ? "border-amber-200 bg-amber-50 hover:border-amber-300"
                      : "border-slate-200 bg-white hover:border-violet-200 hover:bg-violet-50",
                  )}
                >
                  <div className="flex items-center justify-between">
                    <div className="text-lg font-semibold text-slate-950">{table.name}</div>
                    <span className="text-xs text-slate-500">
                      {occupied ? "Dolu / birlestirme gerekebilir" : "Bos masa"}
                    </span>
                  </div>
                  <div className="mt-2 text-sm text-slate-500">
                    {table.zone} • {table.guestCount} kisi • {formatCurrency(calculateGrossTotal(table))}
                  </div>
                </button>
              );
            })}
          </div>
        ) : null}

        {step === 2 && target ? (
          <Panel className="p-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <div className="text-lg font-semibold text-slate-950">{target.name}</div>
                <div className="mt-1 text-sm text-slate-500">
                  {targetOccupied
                    ? "Hedef masa dolu. Guvenli birlestirme akisi secmelisin."
                    : "Hedef masa bos. Tam aktarim guvenli sekilde yapilabilir."}
                </div>
              </div>
              <Button variant="ghost" size="sm" onClick={() => setStep(1)}>
                Hedefi Degistir
              </Button>
            </div>

            <div className="mt-4 grid gap-3 md:grid-cols-3">
              {availableModes.map((entry) => {
                const active = entry === mode;
                return (
                  <button
                    key={entry}
                    onClick={() => setMode(entry)}
                    className={`rounded-[24px] border p-4 text-left transition ${
                      active
                        ? "border-violet-300 bg-violet-50"
                        : "border-slate-200 bg-white"
                    }`}
                  >
                    <div className="text-sm font-semibold text-slate-950">
                      {applyTransferModeLabel(entry)}
                    </div>
                    <div className="mt-1 text-sm text-slate-500">
                      {entry === "all"
                        ? "Tum siparis ve taslak yeni masaya gecer."
                        : entry === "merge"
                          ? "Hedef masa verisi korunur, kaynak siparisler eklenir."
                          : "Sadece bekleyen taslak satirlar tasinir."}
                    </div>
                  </button>
                );
              })}
            </div>

            <div className="mt-5 flex justify-end">
              <Button onClick={() => setStep(3)} disabled={!targetTableId}>
                Onay Ekranina Gec
              </Button>
            </div>
          </Panel>
        ) : null}

        {step === 3 && target ? (
          <Panel className="p-4">
            <div className="text-lg font-semibold text-slate-950">Son onay</div>
            <div className="mt-2 text-sm text-slate-500">
              Kaynak: {sourceTable.name} → Hedef: {target.name}
            </div>
            <div className="mt-3 rounded-[24px] bg-slate-50 p-4 text-sm text-slate-600">
              <div>{applyTransferModeLabel(mode)} secildi.</div>
              <div className="mt-2">
                Aktif siparisler ve taslaklar guvenli sekilde korunacak, islem loglanacak ve masa kartlari aninda guncellenecek.
              </div>
            </div>
            <div className="mt-5 flex flex-col gap-3 sm:flex-row sm:justify-end">
              <Button variant="secondary" onClick={() => setStep(2)}>
                Geri Don
              </Button>
              <Button onClick={() => onConfirm(target.id, mode)}>Aktarimi Tamamla</Button>
            </div>
          </Panel>
        ) : null}
      </div>
    </ModalShell>
  );
}

function TransferMetric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[22px] bg-slate-50 px-4 py-3">
      <div className="text-xs uppercase tracking-[0.16em] text-slate-400">{label}</div>
      <div className="mt-1 text-sm font-semibold text-slate-950">{value}</div>
    </div>
  );
}
