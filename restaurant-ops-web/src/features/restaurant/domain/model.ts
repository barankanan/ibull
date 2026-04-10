export type TableStatus =
  | "empty"
  | "active"
  | "kitchen_sent"
  | "preparing"
  | "ready"
  | "served"
  | "payment_pending"
  | "completed";

export type OrderStatus =
  | "draft"
  | "kitchen_sent"
  | "preparing"
  | "ready"
  | "served"
  | "payment_pending"
  | "completed";

export type ProductKind = "standard" | "weighted" | "service";
export type StockState = "in_stock" | "low" | "out";
export type PaymentMethod = "cash" | "card" | "meal_card" | "qr" | "voucher";
export type SplitMode = "product" | "person" | "amount";
export type TransferMode = "all" | "merge" | "draft-only";
export type DataSourceMode = "mock" | "supabase";
export type ConflictStrategy = "server-wins" | "operator-retry";
export type PrintType = "adisyon" | "mutfak";
export type PrintJobStatus = "pending" | "printed" | "failed";

export interface SnapshotMeta {
  venueId: string;
  source: DataSourceMode;
  fetchedAt: string;
  snapshotVersion: string;
  conflictStrategy: ConflictStrategy;
  optimisticEnabled: boolean;
}

export interface ProductCategory {
  id: string;
  name: string;
  description: string;
  sortOrder?: number;
}

export interface Product {
  id: string;
  sku?: string | null;
  name: string;
  categoryId: string;
  price: number;
  kind: ProductKind;
  description: string;
  stockState: StockState;
  stockLabel: string;
  prepMinutes: number;
  visualTone: "plum" | "rose" | "blue" | "mint" | "amber";
  quickWeightOptions?: number[];
  isFavorite?: boolean;
  isPopular?: boolean;
  suggestionIds?: string[];
  tags?: string[];
  version?: number;
}

export interface ItemCustomizations {
  note: string;
  modifiers: string[];
  grams?: number;
}

export interface ServiceChildItem {
  id: string;
  productId: string;
  name: string;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
  plateNumber: number | null;
  note: string;
  modifiers: string[];
}

export interface ServiceConfiguration {
  serviceName: string;
  orderName: string;
  structure: "standard" | "1_plate" | "2_plate" | "3_plate" | "4_plate" | "5_plate";
  plateCount: number;
  note: string;
  items: ServiceChildItem[];
}

export interface OrderItem {
  id: string;
  productId: string;
  name: string;
  kind: ProductKind;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
  status: OrderStatus;
  createdAt: string;
  customizations: ItemCustomizations;
  service?: ServiceConfiguration;
  version?: number;
}

export interface DraftState {
  id?: string;
  items: OrderItem[];
  editingOrderId: string | null;
  updatedAt: string;
  version?: number;
}

export interface TableOrder {
  id: string;
  label: string;
  status: OrderStatus;
  items: OrderItem[];
  totalPrice: number;
  createdAt: string;
  updatedAt: string;
  note?: string;
  version?: number;
  source?: "waiter" | "qr" | "system";
}

export interface PaymentRecord {
  id: string;
  amount: number;
  method: PaymentMethod;
  createdAt: string;
  kind: "partial" | "closing";
  note?: string;
  remainingAfterPayment?: number;
  version?: number;
}

export interface BillSplitPart {
  id: string;
  label: string;
  amount: number;
  lineItemIds: string[];
}

export interface BillSplitPlan {
  id: string;
  mode: SplitMode;
  createdAt: string;
  parts: BillSplitPart[];
  note?: string;
  version?: number;
}

export interface ReservationInfo {
  guestName: string;
  phone: string;
  at: string;
  guestCount: number;
  note: string;
  channel: "phone" | "walk-in" | "app";
}

export interface TimedBilling {
  enabled: boolean;
  startedAt: string;
  ratePerHour: number;
}

export interface OperationLog {
  id: string;
  type: string;
  title: string;
  description: string;
  createdAt: string;
  severity: "info" | "success" | "warning" | "error";
  status?: "pending" | "committed" | "rolled_back";
  tableId?: string | null;
  operationKey?: string;
  actorName?: string | null;
}

export interface PrinterJobLine {
  id: string;
  name: string;
  quantity: number;
  totalPrice: number;
}

export interface PrinterJob {
  id: string;
  venueId?: string;
  tableId: string;
  tableName: string;
  orderId?: string | null;
  orderReference?: string | null;
  printType: PrintType;
  printerTarget?: string | null;
  status: PrintJobStatus;
  items: PrinterJobLine[];
  totalAmount: number;
  requestedBy?: string | null;
  source: "auto_on_submit" | "manual_action";
  createdAt: string;
  printedAt?: string | null;
}

export interface Customer {
  id: string;
  name: string;
  phone: string;
  loyaltyTier: "Yeni" | "Gumus" | "Altin";
  visitCount: number;
  lastVisitAt: string;
  averageSpend: number;
  favoriteProductIds: string[];
  notes: string[];
  company?: string;
  version?: number;
}

export interface RestaurantTable {
  id: string;
  venueId?: string;
  activeSessionId?: string | null;
  name: string;
  zone: string;
  seats: number;
  guestCount: number;
  status: TableStatus;
  openedAt: string;
  lastActionAt: string;
  draft: DraftState;
  orders: TableOrder[];
  payments: PaymentRecord[];
  splitPlans: BillSplitPlan[];
  reservation?: ReservationInfo | null;
  customerId?: string | null;
  referenceCode?: string;
  barcode?: string;
  timedBilling?: TimedBilling;
  logs: OperationLog[];
  version?: number;
  updatedBy?: string | null;
}

export interface RestaurantStoreState {
  tables: RestaurantTable[];
  products: Product[];
  categories: ProductCategory[];
  customers: Customer[];
  printerJobs: PrinterJob[];
  meta: SnapshotMeta;
}
