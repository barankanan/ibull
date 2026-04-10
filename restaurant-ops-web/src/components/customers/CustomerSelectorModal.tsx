"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/Button";
import { ModalShell } from "@/components/ui/ModalShell";
import { Panel } from "@/components/ui/Panel";
import { Customer } from "@/lib/types";
import { formatCurrency, formatShortDate } from "@/lib/utils";

interface CustomerSelectorModalProps {
  open: boolean;
  mode: "select" | "create";
  customers: Customer[];
  currentCustomerId?: string | null;
  onClose: () => void;
  onSelect: (customerId: string | null) => void;
  onCreate: (payload: {
    name: string;
    phone: string;
    company?: string;
    loyaltyTier: Customer["loyaltyTier"];
    favoriteProductIds: string[];
    notes: string[];
  }) => void;
}

export function CustomerSelectorModal({
  open,
  mode,
  customers,
  currentCustomerId,
  onClose,
  onSelect,
  onCreate,
}: CustomerSelectorModalProps) {
  const [activeMode, setActiveMode] = useState<"select" | "create">(mode);
  const [query, setQuery] = useState("");
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [company, setCompany] = useState("");
  const [tier, setTier] = useState<Customer["loyaltyTier"]>("Yeni");

  useEffect(() => {
    if (!open) return;
    setActiveMode(mode);
    setQuery("");
    setName("");
    setPhone("");
    setCompany("");
    setTier("Yeni");
  }, [mode, open]);

  const filtered = customers.filter((customer) =>
    [customer.name, customer.phone, customer.company ?? ""]
      .join(" ")
      .toLowerCase()
      .includes(query.trim().toLowerCase()),
  );

  return (
    <ModalShell
      open={open}
      onClose={onClose}
      title="Musteri Islemleri"
      description="Masaya musteri bagla veya hizli yeni musteri olustur."
      size="lg"
    >
      <div className="space-y-4">
        <div className="flex flex-wrap gap-2">
          {[
            { id: "select", label: "Musteri Sec" },
            { id: "create", label: "Yeni Musteri" },
          ].map((entry) => {
            const active = entry.id === activeMode;
            return (
              <button
                key={entry.id}
                onClick={() => setActiveMode(entry.id as "select" | "create")}
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

        {activeMode === "select" ? (
          <div className="grid gap-4 lg:grid-cols-[0.85fr,1.15fr]">
            <Panel className="p-4">
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Musteri ara..."
                className="h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm outline-none focus:border-violet-300"
              />
              <div className="mt-4 space-y-3">
                <button
                  onClick={() => onSelect(null)}
                  className="w-full rounded-[22px] border border-dashed border-slate-200 bg-slate-50 px-4 py-4 text-left text-sm text-slate-600"
                >
                  Musteri baglama
                </button>
                {filtered.map((customer) => {
                  const active = customer.id === currentCustomerId;
                  return (
                    <button
                      key={customer.id}
                      onClick={() => onSelect(customer.id)}
                      className={`w-full rounded-[22px] border px-4 py-4 text-left transition ${
                        active
                          ? "border-violet-300 bg-violet-50"
                          : "border-slate-200 bg-white"
                      }`}
                    >
                      <div className="text-sm font-semibold text-slate-950">
                        {customer.name}
                      </div>
                      <div className="mt-1 text-sm text-slate-500">{customer.phone}</div>
                      <div className="mt-2 text-xs text-slate-500">
                        {customer.loyaltyTier} • {customer.visitCount} ziyaret
                      </div>
                    </button>
                  );
                })}
              </div>
            </Panel>

            <Panel className="p-4">
              {filtered[0] ? (
                <div>
                  <div className="text-lg font-semibold text-slate-950">{filtered[0].name}</div>
                  <div className="mt-1 text-sm text-slate-500">{filtered[0].phone}</div>
                  <div className="mt-3 rounded-[22px] bg-slate-50 p-4 text-sm text-slate-600">
                    Son ziyaret {formatShortDate(filtered[0].lastVisitAt)} • Ortalama harcama{" "}
                    {formatCurrency(filtered[0].averageSpend)}
                  </div>
                  <div className="mt-4 flex flex-wrap gap-2">
                    {filtered[0].notes.map((entry) => (
                      <span
                        key={entry}
                        className="rounded-full bg-violet-50 px-3 py-1 text-xs text-violet-800"
                      >
                        {entry}
                      </span>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="text-sm text-slate-500">Musteri secildiginde detay burada gorunur.</div>
              )}
            </Panel>
          </div>
        ) : (
          <Panel className="p-4">
            <div className="grid gap-4 md:grid-cols-2">
              <label className="block">
                <div className="mb-2 text-sm font-semibold text-slate-950">Ad soyad</div>
                <input
                  value={name}
                  onChange={(event) => setName(event.target.value)}
                  className="h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm"
                />
              </label>
              <label className="block">
                <div className="mb-2 text-sm font-semibold text-slate-950">Telefon</div>
                <input
                  value={phone}
                  onChange={(event) => setPhone(event.target.value)}
                  className="h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm"
                />
              </label>
              <label className="block">
                <div className="mb-2 text-sm font-semibold text-slate-950">Sirket</div>
                <input
                  value={company}
                  onChange={(event) => setCompany(event.target.value)}
                  className="h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm"
                />
              </label>
              <label className="block">
                <div className="mb-2 text-sm font-semibold text-slate-950">Sadakat seviyesi</div>
                <select
                  value={tier}
                  onChange={(event) => setTier(event.target.value as Customer["loyaltyTier"])}
                  className="h-12 w-full rounded-2xl border border-slate-200 px-4 text-sm"
                >
                  <option>Yeni</option>
                  <option>Gumus</option>
                  <option>Altin</option>
                </select>
              </label>
            </div>
            <div className="mt-5 flex flex-col gap-3 sm:flex-row sm:justify-end">
              <Button variant="secondary" onClick={onClose}>
                Vazgec
              </Button>
              <Button
                onClick={() =>
                  onCreate({
                    name,
                    phone,
                    company: company || undefined,
                    loyaltyTier: tier,
                    favoriteProductIds: [],
                    notes: [],
                  })
                }
                disabled={!name.trim() || !phone.trim()}
              >
                Musteriyi Olustur
              </Button>
            </div>
          </Panel>
        )}
      </div>
    </ModalShell>
  );
}
