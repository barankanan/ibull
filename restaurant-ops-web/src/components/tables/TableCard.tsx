import { Button } from "@/components/ui/Button";
import { Panel } from "@/components/ui/Panel";
import { TableStatusBadge } from "@/components/tables/TableStatusBadge";
import {
  calculateDraftTotal,
  calculateGrossTotal,
  calculateRemainingTotal,
  getActiveOrders,
} from "@/lib/restaurant";
import { RestaurantTable } from "@/lib/types";
import {
  cn,
  formatCurrency,
  formatElapsedMinutes,
  formatRelativeTime,
} from "@/lib/utils";

interface TableCardProps {
  table: RestaurantTable;
  selected?: boolean;
  onOpen: () => void;
}

export function TableCard({ table, selected, onOpen }: TableCardProps) {
  const draftCount = table.draft.items.length;
  const activeOrders = getActiveOrders(table);
  const grossTotal = calculateGrossTotal(table);
  const remainingTotal = calculateRemainingTotal(table);
  const draftTotal = calculateDraftTotal(table);

  return (
    <Panel
      className={cn(
        "group cursor-pointer p-5 transition hover:-translate-y-0.5 hover:border-violet-200 hover:shadow-lift",
        selected && "border-violet-300 ring-2 ring-violet-200",
      )}
      onClick={onOpen}
    >
      <div className="flex items-start justify-between gap-4">
        <div>
          <div className="text-xs uppercase tracking-[0.2em] text-slate-400">
            {table.zone}
          </div>
          <div className="mt-1 text-2xl font-semibold text-slate-950">
            {table.name}
          </div>
          <div className="mt-1 text-sm text-slate-500">
            Son islem {formatRelativeTime(table.lastActionAt)}
          </div>
        </div>
        <TableStatusBadge status={table.status} />
      </div>

      <div className="mt-5 grid grid-cols-2 gap-3 text-sm md:grid-cols-4">
        <Metric label="Kisi" value={`${table.guestCount}/${table.seats}`} />
        <Metric label="Masa suresi" value={formatElapsedMinutes(table.openedAt)} />
        <Metric label="Taslak" value={`${draftCount} kalem`} />
        <Metric label="Aktif siparis" value={`${activeOrders.length} fis`} />
      </div>

      <div className="mt-5 grid grid-cols-2 gap-3">
        <div className="rounded-[22px] bg-slate-950 px-4 py-3 text-white">
          <div className="text-xs uppercase tracking-[0.18em] text-white/60">
            Toplam
          </div>
          <div className="mt-1 text-xl font-semibold">{formatCurrency(grossTotal)}</div>
        </div>
        <div className="rounded-[22px] bg-violet-50 px-4 py-3 text-violet-950">
          <div className="text-xs uppercase tracking-[0.18em] text-violet-500">
            Kalan
          </div>
          <div className="mt-1 text-xl font-semibold">{formatCurrency(remainingTotal)}</div>
        </div>
      </div>

      <div className="mt-4 flex flex-wrap items-center gap-2 text-xs">
        {draftCount > 0 ? (
          <span className="rounded-full bg-amber-50 px-3 py-1 text-amber-700">
            Taslak {formatCurrency(draftTotal)}
          </span>
        ) : null}
        {table.reservation ? (
          <span className="rounded-full bg-blue-50 px-3 py-1 text-blue-700">
            Rezervasyon var
          </span>
        ) : null}
        {table.referenceCode ? (
          <span className="rounded-full bg-slate-100 px-3 py-1 text-slate-700">
            Kod {table.referenceCode}
          </span>
        ) : null}
      </div>

      <div className="mt-5 flex items-center justify-between gap-3">
        <div className="text-sm text-slate-500">
          Yogun saatte tek dokunusla acilir
        </div>
        <Button variant="secondary" size="sm">
          Masayi Ac
        </Button>
      </div>
    </Panel>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[20px] bg-slate-50 px-3 py-3">
      <div className="text-xs uppercase tracking-[0.16em] text-slate-400">{label}</div>
      <div className="mt-1 text-sm font-semibold text-slate-900">{value}</div>
    </div>
  );
}
