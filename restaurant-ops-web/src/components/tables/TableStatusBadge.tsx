import { ORDER_STATUS_META, TABLE_STATUS_META } from "@/lib/restaurant";
import { OrderStatus, TableStatus } from "@/lib/types";
import { cn } from "@/lib/utils";

interface TableStatusBadgeProps {
  status: TableStatus | OrderStatus;
  compact?: boolean;
}

export function TableStatusBadge({
  status,
  compact = false,
}: TableStatusBadgeProps) {
  const meta =
    status in TABLE_STATUS_META
      ? TABLE_STATUS_META[status as TableStatus]
      : ORDER_STATUS_META[status as OrderStatus];

  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full font-medium",
        compact ? "px-2.5 py-1 text-xs" : "px-3 py-1.5 text-xs",
        meta.className,
      )}
    >
      {meta.label}
    </span>
  );
}
