import { cn } from "@/lib/utils";

interface TabItem {
  id: string;
  label: string;
  count?: number;
}

interface TabsProps {
  items: TabItem[];
  value: string;
  onChange: (value: string) => void;
}

export function Tabs({ items, value, onChange }: TabsProps) {
  return (
    <div className="inline-flex rounded-[24px] border border-white/70 bg-slate-100/80 p-1">
      {items.map((item) => {
        const active = item.id === value;
        return (
          <button
            key={item.id}
            onClick={() => onChange(item.id)}
            className={cn(
              "min-w-[112px] rounded-[20px] px-4 py-3 text-sm font-medium transition",
              active
                ? "bg-white text-slate-950 shadow-soft"
                : "text-slate-500 hover:text-slate-900",
            )}
          >
            <span>{item.label}</span>
            {typeof item.count === "number" ? (
              <span className="ml-2 rounded-full bg-slate-100 px-2 py-0.5 text-xs text-slate-600">
                {item.count}
              </span>
            ) : null}
          </button>
        );
      })}
    </div>
  );
}
