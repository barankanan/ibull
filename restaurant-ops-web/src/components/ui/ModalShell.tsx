import { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface ModalShellProps {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children: ReactNode;
  size?: "md" | "lg" | "xl";
  hideHeader?: boolean;
}

const sizeClasses = {
  md: "max-w-2xl",
  lg: "max-w-4xl",
  xl: "max-w-6xl",
};

export function ModalShell({
  open,
  onClose,
  title,
  description,
  children,
  size = "lg",
  hideHeader = false,
}: ModalShellProps) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[70] flex items-end justify-center bg-slate-950/35 p-3 md:items-center md:p-6">
      <div
        className={cn(
          "glass-panel shell-scrollbar max-h-[92vh] w-full overflow-auto rounded-[32px] border border-white/70 bg-white/95 p-5 shadow-lift md:p-6",
          sizeClasses[size],
        )}
      >
        {!hideHeader ? (
          <div className="mb-5 flex items-start justify-between gap-4">
            <div>
              <h2 className="text-xl font-semibold text-slate-950">{title}</h2>
              {description ? (
                <p className="mt-1 max-w-2xl text-sm text-slate-600">{description}</p>
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
        ) : null}
        {children}
      </div>
    </div>
  );
}
