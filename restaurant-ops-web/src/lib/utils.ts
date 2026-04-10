export function cn(...values: Array<string | false | null | undefined>) {
  return values.filter(Boolean).join(" ");
}

export function formatCurrency(value: number) {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency: "TRY",
    maximumFractionDigits: 2,
  }).format(value);
}

export function formatShortDate(dateText: string) {
  return new Intl.DateTimeFormat("tr-TR", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(dateText));
}

export function formatClock(dateText: string) {
  return new Intl.DateTimeFormat("tr-TR", {
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(dateText));
}

export function formatRelativeTime(dateText: string) {
  const delta = Date.now() - new Date(dateText).getTime();
  const minutes = Math.max(1, Math.floor(delta / 60000));
  if (minutes < 60) {
    return `${minutes} dk once`;
  }
  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours} sa once`;
  }
  const days = Math.floor(hours / 24);
  return `${days} gun once`;
}

export function formatElapsedMinutes(dateText: string) {
  const delta = Date.now() - new Date(dateText).getTime();
  const minutes = Math.max(0, Math.floor(delta / 60000));
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours === 0) {
    return `${rest} dk`;
  }
  return `${hours} sa ${rest} dk`;
}

export function roundCurrency(value: number) {
  return Math.round(value * 100) / 100;
}

export function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

export function makeId(prefix: string) {
  return `${prefix}-${Math.random().toString(36).slice(2, 10)}`;
}
