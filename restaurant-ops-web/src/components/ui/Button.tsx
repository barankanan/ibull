import { ButtonHTMLAttributes, ReactNode } from "react";
import { cn } from "@/lib/utils";

type ButtonVariant = "primary" | "secondary" | "ghost" | "danger" | "soft";
type ButtonSize = "sm" | "md" | "lg";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  leading?: ReactNode;
  trailing?: ReactNode;
  fullWidth?: boolean;
}

const variants: Record<ButtonVariant, string> = {
  primary:
    "bg-slate-950 text-white shadow-[0_16px_32px_rgba(16,24,40,0.16)] hover:bg-slate-900",
  secondary:
    "bg-white text-slate-900 border border-slate-200 hover:border-violet-200 hover:bg-violet-50",
  ghost: "bg-transparent text-slate-700 hover:bg-white/70",
  danger: "bg-rose-600 text-white hover:bg-rose-700",
  soft: "bg-violet-100 text-violet-900 hover:bg-violet-200",
};

const sizes: Record<ButtonSize, string> = {
  sm: "h-10 rounded-2xl px-3 text-sm",
  md: "h-12 rounded-2xl px-4 text-sm",
  lg: "h-14 rounded-2xl px-5 text-base",
};

export function Button({
  className,
  children,
  variant = "primary",
  size = "md",
  leading,
  trailing,
  fullWidth,
  ...props
}: ButtonProps) {
  return (
    <button
      className={cn(
        "inline-flex items-center justify-center gap-2 font-medium transition disabled:cursor-not-allowed disabled:opacity-50",
        variants[variant],
        sizes[size],
        fullWidth && "w-full",
        className,
      )}
      {...props}
    >
      {leading}
      <span>{children}</span>
      {trailing}
    </button>
  );
}
