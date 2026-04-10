import { ORDER_TIMELINE } from "@/lib/restaurant";
import { OrderStatus } from "@/lib/types";
import { cn, formatClock } from "@/lib/utils";

interface StatusTimelineProps {
  status: OrderStatus;
  updatedAt?: string;
}

export function StatusTimeline({ status, updatedAt }: StatusTimelineProps) {
  const activeIndex = ORDER_TIMELINE.findIndex((step) => step.id === status);

  return (
    <div className="rounded-[28px] border border-slate-200 bg-white p-4">
      <div className="mb-4 flex items-center justify-between">
        <div>
          <div className="text-sm font-semibold text-slate-950">Siparis Durum Akisi</div>
          <div className="text-xs text-slate-500">
            {updatedAt ? `Son guncelleme ${formatClock(updatedAt)}` : "Canli takip"}
          </div>
        </div>
      </div>
      <div className="space-y-3">
        {ORDER_TIMELINE.map((step, index) => {
          const done = index <= activeIndex;
          return (
            <div key={step.id} className="flex items-center gap-3">
              <div
                className={cn(
                  "flex h-8 w-8 items-center justify-center rounded-full border text-xs font-semibold",
                  done
                    ? "border-violet-600 bg-violet-600 text-white"
                    : "border-slate-200 bg-slate-50 text-slate-400",
                )}
              >
                {index + 1}
              </div>
              <div className={cn("text-sm", done ? "text-slate-900" : "text-slate-400")}>
                {step.label}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
