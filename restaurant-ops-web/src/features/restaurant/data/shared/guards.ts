import { RestaurantMutationInput } from "@/features/restaurant/domain/commands";
import { RestaurantRuntimeError } from "@/features/restaurant/domain/errors";
import { RestaurantStoreState } from "@/features/restaurant/domain/model";
import {
  calculateRemainingTotal,
  getActiveOrders,
} from "@/lib/restaurant";
import { roundCurrency } from "@/lib/utils";

function findTable(state: RestaurantStoreState, tableId: string) {
  const table = state.tables.find((entry) => entry.id === tableId);
  if (!table) {
    throw new RestaurantRuntimeError(
      "TABLE_NOT_FOUND",
      `Table ${tableId} could not be found.`,
    );
  }
  return table;
}

function assertRevision(
  actual: number,
  expected: number | undefined,
  tableId: string,
  state: RestaurantStoreState,
) {
  if (typeof expected !== "number") return;
  if (actual !== expected) {
    throw new RestaurantRuntimeError(
      "TABLE_VERSION_CONFLICT",
      "Masa baska bir kullanici tarafindan guncellenmis.",
      {
        retriable: true,
        snapshot: state,
        details: {
          tableId,
          actual,
          expected,
        },
      },
    );
  }
}

export function validateRestaurantMutation(
  state: RestaurantStoreState,
  mutation: RestaurantMutationInput,
) {
  if ("tableId" in mutation) {
    const table = findTable(state, mutation.tableId);
    assertRevision(table.version ?? 0, mutation.expectedTableVersion, mutation.tableId, state);
  }

  if ("sourceTableId" in mutation) {
    const source = findTable(state, mutation.sourceTableId);
    const target = findTable(state, mutation.targetTableId);
    assertRevision(source.version ?? 0, mutation.expectedTableVersion, source.id, state);
    assertRevision(
      target.version ?? 0,
      mutation.expectedTargetTableVersion,
      target.id,
      state,
    );
    if (source.id === target.id) {
      throw new RestaurantRuntimeError(
        "INVALID_TRANSFER",
        "Kaynak ve hedef masa ayni olamaz.",
      );
    }
    if (
      mutation.type === "TRANSFER_TABLE" &&
      mutation.mode === "all" &&
      (target.orders.length > 0 || target.draft.items.length > 0)
    ) {
      throw new RestaurantRuntimeError(
        "TARGET_OCCUPIED",
        "Dolu masaya tamamen aktarim yapilamaz. Birlestirme veya sadece taslak aktar sec.",
      );
    }
  }

  switch (mutation.type) {
    case "SEND_DRAFT": {
      const table = findTable(state, mutation.tableId);
      const draft = mutation.draft ?? table.draft;
      if (draft.items.length === 0) {
        throw new RestaurantRuntimeError(
          "EMPTY_DRAFT",
          "Gonderilecek taslak urun bulunamiyor.",
        );
      }
      return;
    }
    case "ADD_PARTIAL_PAYMENT":
    case "CLOSE_BILL": {
      const table = findTable(state, mutation.tableId);
      const remaining = calculateRemainingTotal(table);
      if (mutation.amount <= 0) {
        throw new RestaurantRuntimeError(
          "INVALID_PAYMENT_AMOUNT",
          "Odeme tutari sifirdan buyuk olmalidir.",
        );
      }
      if (roundCurrency(mutation.amount) > roundCurrency(remaining)) {
        throw new RestaurantRuntimeError(
          "PAYMENT_EXCEEDS_BALANCE",
          "Ara odeme kalan tutari gecemez.",
        );
      }
      if (
        mutation.type === "CLOSE_BILL" &&
        table.draft.items.length > 0
      ) {
        throw new RestaurantRuntimeError(
          "DRAFT_BLOCKS_CLOSING",
          "Hesap kapatmadan once bekleyen taslagi gonder veya temizle.",
        );
      }
      return;
    }
    case "CREATE_SPLIT_PLAN": {
      const table = findTable(state, mutation.tableId);
      const expected = roundCurrency(calculateRemainingTotal(table));
      const actual = roundCurrency(
        mutation.plan.parts.reduce((sum, part) => sum + part.amount, 0),
      );
      if (mutation.plan.parts.length < 2) {
        throw new RestaurantRuntimeError(
          "SPLIT_PLAN_TOO_SMALL",
          "Fis bolme plani en az iki parcadan olusmalidir.",
        );
      }
      if (mutation.plan.parts.some((part) => part.amount <= 0)) {
        throw new RestaurantRuntimeError(
          "SPLIT_PLAN_INVALID_PART",
          "Bolunmus parcalar sifirdan buyuk olmalidir.",
        );
      }
      if (expected !== actual) {
        throw new RestaurantRuntimeError(
          "SPLIT_PLAN_MISMATCH",
          "Fis bolme plani kalan toplam ile birebir eslesmelidir.",
        );
      }
      return;
    }
    case "MOVE_ORDER_ITEMS": {
      if (mutation.itemIds.length === 0) {
        throw new RestaurantRuntimeError(
          "MOVE_ITEMS_EMPTY",
          "Aktarim icin en az bir siparis satiri secilmelidir.",
        );
      }
      return;
    }
    case "ASSIGN_CUSTOMER": {
      if (
        mutation.customerId &&
        !state.customers.some((customer) => customer.id === mutation.customerId)
      ) {
        throw new RestaurantRuntimeError(
          "CUSTOMER_NOT_FOUND",
          "Secilen musteri sistemde bulunamadi.",
        );
      }
      return;
    }
    case "CREATE_CUSTOMER_AND_ASSIGN": {
      if (!mutation.customer.name.trim() || !mutation.customer.phone.trim()) {
        throw new RestaurantRuntimeError(
          "CUSTOMER_PAYLOAD_INVALID",
          "Yeni musteri icin ad ve telefon zorunludur.",
        );
      }
      return;
    }
    case "ADVANCE_ORDER_STATUS":
    case "REMOVE_ORDER_ITEM":
    case "UPDATE_ORDER_ITEM": {
      const table = findTable(state, mutation.tableId);
      const orderId = mutation.orderId;
      if (!table.orders.some((order) => order.id === orderId)) {
        throw new RestaurantRuntimeError(
          "ORDER_NOT_FOUND",
          "Siparis bulunamadi.",
        );
      }
      return;
    }
    case "REGISTER_PRINT": {
      const table = findTable(state, mutation.tableId);
      if (getActiveOrders(table).length === 0 && table.draft.items.length === 0) {
        throw new RestaurantRuntimeError(
          "NOTHING_TO_PRINT",
          "Yazdirilacak aktif siparis veya taslak bulunamadi.",
        );
      }
      return;
    }
    default:
      return;
  }
}
