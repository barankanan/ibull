"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/Button";
import { ModalShell } from "@/components/ui/ModalShell";
import { Panel } from "@/components/ui/Panel";
import { calculateGrossTotal } from "@/lib/restaurant";
import { PrinterJob, RestaurantTable } from "@/lib/types";
import { formatClock, formatCurrency } from "@/lib/utils";

interface PrintActionsPanelProps {
  open: boolean;
  table: RestaurantTable | null;
  printerJobs: PrinterJob[];
  initialType?: "adisyon" | "mutfak";
  onClose: () => void;
  onPrint: (type: "adisyon" | "mutfak") => void;
}

export function PrintActionsPanel({
  open,
  table,
  printerJobs,
  initialType = "adisyon",
  onClose,
  onPrint,
}: PrintActionsPanelProps) {
  const [type, setType] = useState<"adisyon" | "mutfak">(initialType);

  useEffect(() => {
    if (!open) return;
    setType(initialType);
  }, [initialType, open]);

  if (!table) return null;

  const printLogs = printerJobs
    .filter((job) => job.tableId === table.id)
    .slice(0, 4);

  return (
    <ModalShell
      open={open}
      onClose={onClose}
      title="Yazdirma / Cikti"
      description="Adisyon ve mutfak ciktilarini ayni panelden yonet."
      size="md"
    >
      <div className="space-y-4">
        <Panel className="p-4">
          <div className="text-sm font-semibold text-slate-950">Hedef cikti</div>
          <div className="mt-3 flex gap-2">
            {[
              { id: "adisyon", label: "Adisyon Yazdir" },
              { id: "mutfak", label: "Mutfaga Yazdir" },
            ].map((entry) => {
              const active = entry.id === type;
              return (
                <button
                  key={entry.id}
                  onClick={() => setType(entry.id as "adisyon" | "mutfak")}
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

        <Panel className="p-4">
          <div className="text-sm font-semibold text-slate-950">Cikti ozeti</div>
          <div className="mt-3 space-y-2 text-sm text-slate-600">
            <div>Masa: {table.name}</div>
            <div>Toplam: {formatCurrency(calculateGrossTotal(table))}</div>
            <div>Aktif fis sayisi: {table.orders.length}</div>
            <div>Taslak kalem: {table.draft.items.length}</div>
          </div>
        </Panel>

        <Panel className="p-4">
          <div className="text-sm font-semibold text-slate-950">Son yazdirma gecmisi</div>
          <div className="mt-3 space-y-2">
            {printLogs.length === 0 ? (
              <div className="text-sm text-slate-500">Henuz yazdirma kaydi yok.</div>
            ) : (
              printLogs.map((log) => (
                <div
                  key={log.id}
                  className="rounded-2xl bg-slate-50 px-3 py-3 text-sm text-slate-600"
                >
                  <div className="font-medium text-slate-950">
                    {log.printType === "adisyon" ? "Adisyon" : "Mutfak"} • {log.status}
                  </div>
                  <div className="mt-1 text-slate-500">
                    {log.orderReference ?? table.name} • {formatCurrency(log.totalAmount)}
                  </div>
                  <div className="mt-1 text-slate-500">{formatClock(log.createdAt)}</div>
                </div>
              ))
            )}
          </div>
        </Panel>

        <div className="flex flex-col gap-3 sm:flex-row sm:justify-end">
          <Button variant="secondary" onClick={onClose}>
            Kapat
          </Button>
          <Button onClick={() => onPrint(type)}>
            {type === "adisyon" ? "Adisyon Yazdir" : "Mutfaga Yazdir"}
          </Button>
        </div>
      </div>
    </ModalShell>
  );
}
