import { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface DrawerShellProps {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children: ReactNode;
  widthClassName?: string;
}

export function DrawerShell({
  open,
  onClose,
  title,
  description,
  children,
  widthClassName = "w-full max-w-[520px]",
}: DrawerShellProps) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[65] bg-slate-950/30">
      <div className="absolute inset-0" onClick={onClose} />
      <div
        className={cn(
          "glass-panel shell-scrollbar absolute right-0 top-0 h-full overflow-auto border-l border-white/70 bg-white/95 p-5 shadow-lift md:p-6",
          widthClassName,
        )}
      >
        <div className="mb-5 flex items-start justify-between gap-4">
          <div>
            <h2 className="text-xl font-semibold text-slate-950">{title}</h2>
            {description ? (
              <p className="mt-1 text-sm text-slate-600">{description}</p>
            ) : null}
          </div>
          <button
            onClick={onClose}
            className="flex h-12 w-12 items-center justify-center rounded-2xl border border-slate-200 bg-white text-lg text-slate-600 transition hover:border-violet-200 hover:text-violet-700"
            aria-label="Kapat"
          >
            ×
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
