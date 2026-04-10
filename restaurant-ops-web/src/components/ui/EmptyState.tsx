import { ReactNode } from "react";
import { Panel } from "@/components/ui/Panel";

interface EmptyStateProps {
  title: string;
  description: string;
  action?: ReactNode;
}

export function EmptyState({ title, description, action }: EmptyStateProps) {
  return (
    <Panel className="border-dashed p-6 text-center">
      <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-3xl bg-violet-100 text-xl text-violet-700">
        •
      </div>
      <h3 className="mt-4 text-lg font-semibold text-slate-950">{title}</h3>
      <p className="mx-auto mt-2 max-w-md text-sm leading-6 text-slate-600">
        {description}
      </p>
      {action ? <div className="mt-4">{action}</div> : null}
    </Panel>
  );
}
