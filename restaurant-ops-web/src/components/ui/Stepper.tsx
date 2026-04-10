import { Button } from "@/components/ui/Button";

interface StepperProps {
  value: number;
  onDecrease: () => void;
  onIncrease: () => void;
  min?: number;
  unitLabel?: string;
  disabled?: boolean;
}

export function Stepper({
  value,
  onDecrease,
  onIncrease,
  min = 0,
  unitLabel,
  disabled = false,
}: StepperProps) {
  return (
    <div className="inline-flex items-center rounded-[20px] border border-slate-200 bg-white p-1">
      <Button
        variant="ghost"
        size="sm"
        onClick={onDecrease}
        disabled={disabled || value <= min}
        className="h-10 w-10 rounded-2xl px-0"
      >
        -
      </Button>
      <div className="min-w-[70px] text-center text-sm font-semibold text-slate-950">
        {value}
        {unitLabel ? ` ${unitLabel}` : ""}
      </div>
      <Button
        variant="ghost"
        size="sm"
        onClick={onIncrease}
        disabled={disabled}
        className="h-10 w-10 rounded-2xl px-0"
      >
        +
      </Button>
    </div>
  );
}
