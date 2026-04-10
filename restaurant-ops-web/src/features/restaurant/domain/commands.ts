import {
  BillSplitPlan,
  Customer,
  DraftState,
  OrderItem,
  PaymentMethod,
  RestaurantStoreState,
  TimedBilling,
  TransferMode,
} from "@/features/restaurant/domain/model";

export interface ActorContext {
  userId?: string | null;
  name?: string | null;
  deviceId?: string | null;
}

export interface MutationMeta {
  clientMutationId: string;
  actor?: ActorContext;
  createdAt: string;
  expectedTableVersion?: number;
  expectedTargetTableVersion?: number;
}

export type RestaurantMutationInput =
  | ({ type: "ADD_DRAFT_ITEM"; tableId: string; item: OrderItem } & MutationMeta)
  | ({
      type: "UPDATE_DRAFT_ITEM";
      tableId: string;
      itemId: string;
      updates: Partial<OrderItem>;
    } & MutationMeta)
  | ({ type: "REMOVE_DRAFT_ITEM"; tableId: string; itemId: string } & MutationMeta)
  | ({ type: "CLEAR_DRAFT"; tableId: string } & MutationMeta)
  | ({ type: "LOAD_ORDER_INTO_DRAFT"; tableId: string; orderId: string } & MutationMeta)
  | ({ type: "SEND_DRAFT"; tableId: string; draft?: DraftState } & MutationMeta)
  | ({ type: "SET_GUEST_COUNT"; tableId: string; guestCount: number } & MutationMeta)
  | ({ type: "ADVANCE_ORDER_STATUS"; tableId: string; orderId: string } & MutationMeta)
  | ({
      type: "UPDATE_ORDER_ITEM";
      tableId: string;
      orderId: string;
      itemId: string;
      updates: Partial<OrderItem>;
    } & MutationMeta)
  | ({
      type: "REMOVE_ORDER_ITEM";
      tableId: string;
      orderId: string;
      itemId: string;
    } & MutationMeta)
  | ({
      type: "ADD_PARTIAL_PAYMENT";
      tableId: string;
      amount: number;
      method: PaymentMethod;
      note?: string;
      kind?: "partial" | "closing";
    } & MutationMeta)
  | ({ type: "ASSIGN_CUSTOMER"; tableId: string; customerId: string | null } & MutationMeta)
  | ({
      type: "CREATE_CUSTOMER_AND_ASSIGN";
      tableId: string;
      customer: Omit<Customer, "id" | "lastVisitAt" | "visitCount" | "averageSpend">;
    } & MutationMeta)
  | ({ type: "CREATE_SPLIT_PLAN"; tableId: string; plan: BillSplitPlan } & MutationMeta)
  | ({
      type: "TRANSFER_TABLE";
      sourceTableId: string;
      targetTableId: string;
      mode: TransferMode;
    } & MutationMeta)
  | ({
      type: "MOVE_ORDER_ITEMS";
      sourceTableId: string;
      targetTableId: string;
      itemIds: string[];
    } & MutationMeta)
  | ({ type: "REGISTER_PRINT"; tableId: string; printType: string } & MutationMeta)
  | ({
      type: "CLOSE_BILL";
      tableId: string;
      method: PaymentMethod;
      note?: string;
      amount: number;
    } & MutationMeta)
  | ({ type: "NEW_BILL"; tableId: string } & MutationMeta)
  | ({ type: "SET_REFERENCE_CODE"; tableId: string; code: string } & MutationMeta)
  | ({ type: "SET_BARCODE"; tableId: string; code: string } & MutationMeta)
  | ({ type: "SET_TIMED_BILLING"; tableId: string; timedBilling: TimedBilling } & MutationMeta)
  | ({
      type: "ADD_LOG";
      tableId: string;
      typeKey: string;
      title: string;
      description: string;
    } & MutationMeta);

export interface RestaurantSnapshotResponse {
  snapshot: RestaurantStoreState;
}

export interface ConflictPayload {
  code: "TABLE_VERSION_CONFLICT";
  message: string;
  latestSnapshot?: RestaurantStoreState;
  tableId?: string;
  latestVersion?: number;
}

export type RestaurantMutationDraft =
  RestaurantMutationInput extends infer Mutation
    ? Mutation extends RestaurantMutationInput
      ? Omit<Mutation, keyof MutationMeta> & Partial<MutationMeta>
      : never
    : never;

export interface RestaurantMutationResult {
  snapshot: RestaurantStoreState;
  appliedMutationId: string;
  operationLogIds: string[];
  changedTableIds: string[];
  conflict?: ConflictPayload;
}
