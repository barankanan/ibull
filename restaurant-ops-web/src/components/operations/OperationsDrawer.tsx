"use client";

import { ReactNode, useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/Button";
import { DrawerShell } from "@/components/ui/DrawerShell";
import { Panel } from "@/components/ui/Panel";
import { Stepper } from "@/components/ui/Stepper";
import { calculateRemainingTotal, getActiveOrders } from "@/lib/restaurant";
import { PaymentMethod, RestaurantTable } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";

interface OperationsDrawerProps {
  open: boolean;
  table: RestaurantTable | null;
  tables: RestaurantTable[];
  onClose: () => void;
  onOpenPartialPayment: () => void;
  onOpenSplitBill: () => void;
  onOpenTransfer: () => void;
  onOpenPrint: (type: "adisyon" | "mutfak") => void;
  onOpenCustomerModal: (mode: "select" | "create") => void;
  onSetGuestCount: (guestCount: number) => void;
  onNewBill: () => void;
  onMoveItems: (targetTableId: string, itemIds: string[]) => void;
  onSetTimedBilling: (enabled: boolean, ratePerHour: number) => void;
  onSetReferenceCode: (code: string) => void;
  onSetBarcode: (code: string) => void;
  onCloseBill: (method: PaymentMethod, note: string) => void;
  onLog: (title: string, description: string) => void;
}

export function OperationsDrawer({
  open,
  table,
  tables,
  onClose,
  onOpenPartialPayment,
  onOpenSplitBill,
  onOpenTransfer,
  onOpenPrint,
  onOpenCustomerModal,
  onSetGuestCount,
  onNewBill,
  onMoveItems,
  onSetTimedBilling,
  onSetReferenceCode,
  onSetBarcode,
  onCloseBill,
  onLog,
}: OperationsDrawerProps) {
  const [closeMethod, setCloseMethod] = useState<PaymentMethod>("card");
  const [closeNote, setCloseNote] = useState("");
  const [moveTarget, setMoveTarget] = useState("");
  const [selectedMoveItems, setSelectedMoveItems] = useState<string[]>([]);
  const [timedEnabled, setTimedEnabled] = useState(false);
  const [timedRate, setTimedRate] = useState("250");
  const [referenceCode, setReferenceCode] = useState("");
  const [barcodeValue, setBarcodeValue] = useState("");
  const closeBillPanelRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!open || !table) return;
    setCloseMethod("card");
    setCloseNote("");
    setMoveTarget("");
    setSelectedMoveItems([]);
    setTimedEnabled(table.timedBilling?.enabled ?? false);
    setTimedRate(String(table.timedBilling?.ratePerHour ?? 250));
    setReferenceCode(table.referenceCode ?? "");
    setBarcodeValue(table.barcode ?? "");
  }, [open, table]);

  if (!table) return null;

  const activeLines = getActiveOrders(table).flatMap((order) =>
    order.items.map((item) => ({
      id: item.id,
      label: `${order.label} • ${item.name}`,
    })),
  );

  return (
    <DrawerShell
      open={open}
      onClose={onClose}
      title="Islemler"
      description="Akınsoft mantigini modern drawer akisi ile hizlandirilmis sekilde sunar."
    >
      <div className="space-y-5">
        <Panel className="p-4">
          <div className="text-sm font-semibold text-slate-950">En sik kullanilanlar</div>
          <div className="mt-4 grid gap-2 sm:grid-cols-2">
            <ActionButton title="Ara Odeme Al" onClick={onOpenPartialPayment} />
            <ActionButton title="Hesabi Bol" onClick={onOpenSplitBill} />
            <ActionButton
              title="Hesabi Kes"
              onClick={() =>
                closeBillPanelRef.current?.scrollIntoView({
                  behavior: "smooth",
                  block: "center",
                })
              }
            />
            <ActionButton title="Masa Aktar" onClick={onOpenTransfer} />
            <ActionButton title="Adisyon Yazdir" onClick={() => onOpenPrint("adisyon")} />
            <ActionButton title="Mutfaga Yazdir" onClick={() => onOpenPrint("mutfak")} />
          </div>
        </Panel>

        <Section title="Odeme Islemleri">
          <ActionButton title="Ara Odeme Al" onClick={onOpenPartialPayment} />
          <ActionButton title="Hesabi Bol" onClick={onOpenSplitBill} />
          <Panel ref={closeBillPanelRef} className="p-4">
            <div className="text-sm font-semibold text-slate-950">Hesabi Kes</div>
            <div className="mt-1 text-sm text-slate-500">
              Kalan tutar {formatCurrency(calculateRemainingTotal(table))}
            </div>
            <div className="mt-3 flex flex-wrap gap-2">
              {[
                { id: "cash", label: "Nakit" },
                { id: "card", label: "Kart" },
                { id: "qr", label: "QR" },
              ].map((entry) => {
                const active = closeMethod === entry.id;
                return (
                  <button
                    key={entry.id}
                    onClick={() => setCloseMethod(entry.id as PaymentMethod)}
                    className={`rounded-2xl px-4 py-2 text-sm ${
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
            <textarea
              value={closeNote}
              onChange={(event) => setCloseNote(event.target.value)}
              rows={3}
              placeholder="Kapanis notu..."
              className="mt-3 w-full rounded-[20px] border border-slate-200 px-3 py-3 text-sm"
            />
            <Button
              className="mt-3"
              fullWidth
              onClick={() => onCloseBill(closeMethod, closeNote)}
            >
              Hesabi Kes
            </Button>
          </Panel>
        </Section>

        <Section title="Yazdirma / Cikti">
          <ActionButton title="Adisyon Yazdir" onClick={() => onOpenPrint("adisyon")} />
          <ActionButton title="Mutfaga Yazdir" onClick={() => onOpenPrint("mutfak")} />
        </Section>

        <Section title="Musteri Islemleri">
          <ActionButton title="Yeni Musteri" onClick={() => onOpenCustomerModal("create")} />
          <ActionButton title="Musteri Sec" onClick={() => onOpenCustomerModal("select")} />
          <Panel className="p-4">
            <div className="text-sm font-semibold text-slate-950">Musteri sayisi</div>
            <div className="mt-3">
              <Stepper
                value={table.guestCount}
                min={0}
                onDecrease={() => onSetGuestCount(Math.max(0, table.guestCount - 1))}
                onIncrease={() => onSetGuestCount(table.guestCount + 1)}
              />
            </div>
          </Panel>
        </Section>

        <Section title="Masa / Fis Operasyonlari">
          <ActionButton title="Yeni Fis" onClick={onNewBill} />
          <ActionButton title="Masa Aktar" onClick={onOpenTransfer} />
          <ActionButton title="Hesabi Bol" onClick={onOpenSplitBill} />
          <Panel className="p-4">
            <div className="text-sm font-semibold text-slate-950">Hareket Aktar</div>
            <div className="mt-1 text-sm text-slate-500">
              Secili siparis satirlarini baska masanin taslagina aktar.
            </div>
            <div className="mt-3 space-y-2">
              {activeLines.map((line) => {
                const active = selectedMoveItems.includes(line.id);
                return (
                  <button
                    key={line.id}
                    onClick={() =>
                      setSelectedMoveItems((current) =>
                        active
                          ? current.filter((itemId) => itemId !== line.id)
                          : [...current, line.id],
                      )
                    }
                    className={`flex w-full items-center justify-between rounded-2xl border px-3 py-3 text-left text-sm ${
                      active
                        ? "border-violet-300 bg-violet-50 text-violet-900"
                        : "border-slate-200 bg-white text-slate-600"
                    }`}
                  >
                    <span>{line.label}</span>
                    <span>{active ? "Secildi" : "Sec"}</span>
                  </button>
                );
              })}
            </div>
            <select
              value={moveTarget}
              onChange={(event) => setMoveTarget(event.target.value)}
              className="mt-3 h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm"
            >
              <option value="">Hedef masa sec</option>
              {tables
                .filter((entry) => entry.id !== table.id)
                .map((entry) => (
                  <option key={entry.id} value={entry.id}>
                    {entry.name}
                  </option>
                ))}
            </select>
            <Button
              className="mt-3"
              fullWidth
              onClick={() => onMoveItems(moveTarget, selectedMoveItems)}
              disabled={!moveTarget || selectedMoveItems.length === 0}
            >
              Secili Hareketleri Aktar
            </Button>
          </Panel>
        </Section>

        <Section title="Ek Araclar">
          <Panel className="p-4">
            <div className="text-sm font-semibold text-slate-950">Sureli Hesap</div>
            <div className="mt-3 flex items-center justify-between rounded-2xl bg-slate-50 px-3 py-3">
              <span className="text-sm text-slate-600">Aktif / pasif</span>
              <button
                onClick={() => setTimedEnabled((current) => !current)}
                className={`rounded-full px-4 py-2 text-sm ${
                  timedEnabled ? "bg-violet-600 text-white" : "bg-slate-200 text-slate-700"
                }`}
              >
                {timedEnabled ? "Aktif" : "Pasif"}
              </button>
            </div>
            <input
              value={timedRate}
              onChange={(event) => setTimedRate(event.target.value)}
              type="number"
              min="0"
              className="mt-3 h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm"
              placeholder="Saatlik tutar"
            />
            <Button
              className="mt-3"
              fullWidth
              onClick={() => onSetTimedBilling(timedEnabled, Number(timedRate || 0))}
            >
              Sureli Hesabi Kaydet
            </Button>
          </Panel>

          <Panel className="p-4">
            <div className="text-sm font-semibold text-slate-950">Ozel Kod Ver</div>
            <input
              value={referenceCode}
              onChange={(event) => setReferenceCode(event.target.value)}
              className="mt-3 h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm"
              placeholder="Referans kodu"
            />
            <Button className="mt-3" fullWidth onClick={() => onSetReferenceCode(referenceCode)}>
              Kodu Kaydet
            </Button>
          </Panel>

          <Panel className="p-4">
            <div className="text-sm font-semibold text-slate-950">Kredi Karti Kullan</div>
            <div className="mt-2 text-sm text-slate-500">
              Mock akista sonraki odeme icin kart kanalini one cikarir.
            </div>
            <Button
              className="mt-3"
              fullWidth
              variant="secondary"
              onClick={() => {
                setCloseMethod("card");
                onLog("Kredi karti modu secildi", "Sonraki odeme icin kart tercihi one alindi.");
              }}
            >
              Kart Modunu Hazirla
            </Button>
          </Panel>

          <Panel className="p-4">
            <div className="text-sm font-semibold text-slate-950">Barkod Ver / Okut</div>
            <input
              value={barcodeValue}
              onChange={(event) => setBarcodeValue(event.target.value)}
              className="mt-3 h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm"
              placeholder="Barkod degeri"
            />
            <div className="mt-3 grid gap-2 sm:grid-cols-2">
              <Button variant="secondary" onClick={() => onSetBarcode(barcodeValue || `BAR-${table.name}`)}>
                Barkod Ver
              </Button>
              <Button
                variant="ghost"
                onClick={() =>
                  onLog(
                    "Barkod okut simule edildi",
                    `${barcodeValue || "placeholder"} degeri cihaz entegrasyonuna hazir akista okundu.`,
                  )
                }
              >
                Barkod Okut
              </Button>
            </div>
          </Panel>
        </Section>
      </div>
    </DrawerShell>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <div className="space-y-3">
      <div className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">
        {title}
      </div>
      <div className="space-y-3">{children}</div>
    </div>
  );
}

function ActionButton({
  title,
  onClick,
}: {
  title: string;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className="w-full rounded-[22px] border border-slate-200 bg-white px-4 py-4 text-left text-sm font-medium text-slate-900 transition hover:border-violet-200 hover:bg-violet-50"
    >
      {title}
    </button>
  );
}
