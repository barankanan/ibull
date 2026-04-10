import { HTMLAttributes, forwardRef } from "react";
import { cn } from "@/lib/utils";

export const Panel = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
  function Panel({ className, ...props }, ref) {
    return (
      <div
        ref={ref}
        className={cn(
          "glass-panel rounded-[28px] border border-white/60 bg-white/90",
          className,
        )}
        {...props}
      />
    );
  },
);
