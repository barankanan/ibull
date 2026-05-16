from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal, InvalidOperation
import logging
from typing import Any


class PayloadError(ValueError):
    """Raised when an incoming JSON payload is invalid."""


LOGGER = logging.getLogger("print_bridge.models")


def _resolve_printable_item_name(d: dict[str, Any]) -> str:
    """Resolve item name across SQL + Flutter payload variants."""
    for k in ("product_name", "item_name", "display_name", "name", "title"):
        v = d.get(k)
        if v is None:
            continue
        s = str(v).strip()
        if s:
            return s
    return "Ürün"


def _resolve_printable_note(d: dict[str, Any]) -> str:
    """Resolve note across SQL + Flutter payload variants."""
    for k in ("note", "notes", "item_note"):
        v = d.get(k)
        if v is None:
            continue
        s = str(v).strip()
        if s:
            return s
    return ""


def _expect_mapping(value: Any, field_name: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise PayloadError(f"`{field_name}` must be an object.")
    return value


def _expect_string(value: Any, field_name: str, *, required: bool = True) -> str:
    if value is None:
        if required:
            raise PayloadError(f"`{field_name}` is required.")
        return ""
    text = str(value).strip()
    if required and not text:
        raise PayloadError(f"`{field_name}` cannot be empty.")
    return text


def _expect_decimal(
    value: Any,
    field_name: str,
    *,
    required: bool = True,
    minimum: Decimal | None = None,
) -> Decimal:
    if value is None:
        if required:
            raise PayloadError(f"`{field_name}` is required.")
        return Decimal("0")
    try:
        decimal_value = Decimal(str(value))
    except (InvalidOperation, TypeError) as exc:
        raise PayloadError(f"`{field_name}` must be numeric.") from exc
    if minimum is not None and decimal_value < minimum:
        raise PayloadError(f"`{field_name}` must be at least {minimum}.")
    return decimal_value


def _coerce_decimal(
    value: Any,
    field_name: str,
    *,
    minimum: Decimal | None = None,
) -> Decimal | None:
    if value is None:
        return None
    return _expect_decimal(value, field_name, required=True, minimum=minimum)


def _parse_datetime(value: Any) -> datetime:
    if value in (None, ""):
        return datetime.now().astimezone()
    if isinstance(value, datetime):
        return value
    raw = str(value).strip()
    if not raw:
        return datetime.now().astimezone()
    normalized = raw.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        raise PayloadError(
            "`date_time`/`datetime` must be ISO-8601 compatible, for example 2026-04-08T14:35:00+03:00."
        ) from None
    return parsed.astimezone() if parsed.tzinfo else parsed


@dataclass(frozen=True)
class ReceiptItem:
    name: str
    quantity: Decimal
    line_total: Decimal
    unit_price: Decimal | None = None
    note: str = ""

    @classmethod
    def from_dict(cls, payload: Any) -> "ReceiptItem":
        data = _expect_mapping(payload, "items[]")
        quantity = _expect_decimal(
            data.get("quantity", data.get("qty", 1)),
            "items[].quantity",
            minimum=Decimal("0.001"),
        )
        unit_price = _coerce_decimal(
            data.get("unit_price", data.get("price")),
            "items[].unit_price",
            minimum=Decimal("0"),
        )
        line_total = _coerce_decimal(
            data.get("line_total", data.get("total")),
            "items[].line_total",
            minimum=Decimal("0"),
        )
        if line_total is None:
            if unit_price is None:
                raise PayloadError(
                    "`items[].line_total` is required when `items[].unit_price` is missing."
                )
            line_total = quantity * unit_price
        return cls(
            name=_expect_string(data.get("name"), "items[].name"),
            quantity=quantity,
            line_total=line_total,
            unit_price=unit_price,
            note=_expect_string(data.get("note", data.get("notes")), "items[].note", required=False),
        )


@dataclass(frozen=True)
class ReceiptTotals:
    subtotal: Decimal
    discount: Decimal
    service_charge: Decimal
    grand_total: Decimal

    @classmethod
    def from_payload(
        cls,
        payload: Any,
        *,
        items: list[ReceiptItem],
    ) -> "ReceiptTotals":
        root = _expect_mapping(payload, "payload")
        data = _expect_mapping(root.get("totals"), "totals") if root.get("totals") is not None else root
        subtotal = _coerce_decimal(
            data.get("subtotal", data.get("sub_total")),
            "subtotal",
            minimum=Decimal("0"),
        )
        if subtotal is None:
            subtotal = sum((item.line_total for item in items), Decimal("0"))
        discount = _expect_decimal(
            data.get("discount"),
            "discount",
            required=False,
            minimum=Decimal("0"),
        )
        service_charge = _expect_decimal(
            data.get("service_charge", data.get("service")),
            "service_charge",
            required=False,
            minimum=Decimal("0"),
        )
        grand_total = _coerce_decimal(
            data.get("grand_total", data.get("total")),
            "grand_total",
            minimum=Decimal("0"),
        )
        if grand_total is None:
            grand_total = subtotal - discount + service_charge
        return cls(
            subtotal=subtotal,
            discount=discount,
            service_charge=service_charge,
            grand_total=grand_total,
        )


@dataclass(frozen=True)
class ReceiptPayload:
    store_name: str
    branch: str
    phone: str
    table_no: str
    date_time: datetime
    items: list[ReceiptItem]
    totals: ReceiptTotals
    currency: str
    footer_note: str
    table_name: str = ""
    table_area_name: str = ""
    area_name: str = ""
    area_table_number: str = ""
    # Optional header timestamps (payload metadata)
    receipt_printed_at: str = ""
    printed_at: str = ""
    order_created_at: str = ""
    created_at: str = ""

    @classmethod
    def from_dict(cls, payload: Any) -> "ReceiptPayload":
        data = _expect_mapping(payload, "payload")
        raw_items = data.get("items")
        if not isinstance(raw_items, list) or not raw_items:
            raise PayloadError("`items` must be a non-empty array.")
        items = [ReceiptItem.from_dict(item) for item in raw_items]
        receipt_printed_at = str(data.get("receipt_printed_at") or "").strip()
        printed_at = str(data.get("printed_at") or "").strip()
        order_created_at = str(data.get("order_created_at") or "").strip()
        created_at = str(data.get("created_at") or "").strip()
        resolved_dt_source: Any = (
            receipt_printed_at
            or printed_at
            or order_created_at
            or created_at
            or data.get("date_time")
            or data.get("datetime")
            or data.get("dateTime")
        )

        return cls(
            store_name=_expect_string(
                data.get("store_name", data.get("storeName")),
                "store_name",
            ),
            branch=_expect_string(data.get("branch"), "branch", required=False),
            phone=_expect_string(data.get("phone"), "phone", required=False),
            table_no=_expect_string(
                data.get("table_no", data.get("tableNo", data.get("table_number"))),
                "table_no",
            ),
            table_name=_expect_string(
                data.get(
                    "display_table_label",
                    data.get("table_display_name", data.get("table_name", "")),
                ),
                "table_name",
                required=False,
            ),
            table_area_name=_expect_string(
                data.get("table_area_name", data.get("area_name", "")),
                "table_area_name",
                required=False,
            ),
            area_name=_expect_string(data.get("area_name", ""), "area_name", required=False),
            area_table_number=_expect_string(
                str(data.get("area_table_number", "")) if data.get("area_table_number") is not None else "",
                "area_table_number",
                required=False,
            ),
            receipt_printed_at=receipt_printed_at,
            printed_at=printed_at,
            order_created_at=order_created_at,
            created_at=created_at,
            date_time=_parse_datetime(resolved_dt_source),
            items=items,
            totals=ReceiptTotals.from_payload(data, items=items),
            currency=_expect_string(data.get("currency", "TRY"), "currency"),
            footer_note=_expect_string(
                data.get("footer_note", data.get("footerNote")),
                "footer_note",
                required=False,
            ),
        )


# ---------------------------------------------------------------------------
# Kitchen print models
# ---------------------------------------------------------------------------
# These represent the payload produced by Flutter's _buildKitchenPayload() and
# received at POST /print/kitchen.  They are intentionally separate from the
# receipt models: kitchen tickets show item names + quantities only, with no
# pricing information.


@dataclass(frozen=True)
class KitchenChildItem:
    """A child item inside a service plate or service_children list."""

    id: str
    name: str
    quantity: int
    amount_label: str = ""
    note: str = ""
    station_id: str = ""

    @classmethod
    def from_dict(cls, data: Any) -> "KitchenChildItem":
        d = _expect_mapping(data, "child_item")
        resolved_name = _resolve_printable_item_name(d)
        return cls(
            id=_expect_string(d.get("id", ""), "child_item.id", required=False),
            name=_expect_string(
                resolved_name,
                "child_item.name",
                required=False,
            ),
            quantity=max(1, int(d.get("quantity", 1) or 1)),
            amount_label=_expect_string(
                d.get("amount_label", ""), "child_item.amount_label", required=False
            ),
            note=_expect_string(
                _resolve_printable_note(d),
                "child_item.note",
                required=False,
            ),
            station_id=_expect_string(
                d.get("station_id", ""), "child_item.station_id", required=False
            ),
        )


@dataclass(frozen=True)
class KitchenPlate:
    """A service plate (tabak) grouping child items for service-based dishes."""

    label: str
    items: tuple["KitchenChildItem", ...]

    @classmethod
    def from_dict(cls, data: Any) -> "KitchenPlate":
        d = _expect_mapping(data, "plate")
        label = _expect_string(d.get("label", "Tabak"), "plate.label", required=False)
        raw_items = d.get("items", [])
        items = tuple(
            KitchenChildItem.from_dict(item)
            for item in (raw_items if isinstance(raw_items, list) else [])
        )
        return cls(label=label, items=items)


@dataclass(frozen=True)
class KitchenItem:
    """A single line item on a kitchen print ticket."""

    id: str
    name: str
    quantity: int
    note: str = ""
    amount_label: str = ""
    plates: tuple[KitchenPlate, ...] = ()
    service_children: tuple[KitchenChildItem, ...] = ()

    @classmethod
    def from_dict(cls, data: Any) -> "KitchenItem":
        d = _expect_mapping(data, "items[]")
        raw_plates = d.get("plates", [])
        plates = tuple(
            KitchenPlate.from_dict(p)
            for p in (raw_plates if isinstance(raw_plates, list) else [])
        )
        raw_children = d.get("service_children", [])
        service_children = tuple(
            KitchenChildItem.from_dict(c)
            for c in (raw_children if isinstance(raw_children, list) else [])
        )
        resolved_name = _resolve_printable_item_name(d)
        if resolved_name == "Ürün":
            LOGGER.warning(
                "kitchen_item_missing_name productId=%s orderItemId=%s rawItem=%s",
                d.get("product_id", "-"),
                d.get("order_item_id", d.get("id", "-")),
                {
                    k: d.get(k)
                    for k in (
                        "product_id",
                        "order_item_id",
                        "id",
                        "name",
                        "item_name",
                        "product_name",
                        "display_name",
                        "title",
                    )
                },
            )
        return cls(
            id=_expect_string(
                d.get("id", d.get("order_item_id", "")),
                "items[].id",
                required=False,
            ),
            name=_expect_string(
                resolved_name,
                "items[].name",
                required=False,
            ),
            quantity=max(1, int(d.get("quantity", 1) or 1)),
            note=_expect_string(
                _resolve_printable_note(d),
                "items[].note",
                required=False,
            ),
            amount_label=_expect_string(
                d.get("amount_label", ""), "items[].amount_label", required=False
            ),
            plates=plates,
            service_children=service_children,
        )


@dataclass(frozen=True)
class KitchenPayload:
    """Full kitchen ticket payload from Flutter's _buildKitchenPayload()."""

    title: str
    store_name: str
    order_no: str
    table_no: str
    table_name: str
    table_area_name: str
    area_name: str
    waiter_name: str
    job_type: str
    date_time: datetime
    items: tuple[KitchenItem, ...]
    # Optional header metadata (print_jobs.payload)
    order_number: str = ""
    order_id: str = ""
    daily_order_no: int = 0
    kitchen_order_no: int = 0
    printed_at: str = ""
    kitchen_printed_at: str = ""
    created_at: str = ""
    order_created_at: str = ""
    table_number: int = 0
    area_table_number: int = 0
    table_display_name: str = ""
    display_table_label: str = ""

    @classmethod
    def from_dict(cls, data: Any) -> "KitchenPayload":
        d = _expect_mapping(data, "kitchen_payload")
        raw_items = d.get("items", [])
        items = tuple(
            KitchenItem.from_dict(item)
            for item in (raw_items if isinstance(raw_items, list) else [])
        )

        def _txt(value: Any) -> str:
            return str(value or "").strip()

        def _int(value: Any) -> int:
            try:
                if value is None or isinstance(value, bool):
                    return 0
                return int(str(value).strip() or "0")
            except Exception:
                return 0

        printed_at = _txt(d.get("printed_at"))
        kitchen_printed_at = _txt(d.get("kitchen_printed_at"))
        order_created_at = _txt(d.get("order_created_at"))
        created_at = _txt(d.get("created_at", d.get("date_time", d.get("datetime"))))
        resolved_dt_source: Any = (
            printed_at
            or kitchen_printed_at
            or order_created_at
            or created_at
            or d.get("datetime", d.get("created_at", d.get("date_time")))
        )
        resolved_dt = _parse_datetime(resolved_dt_source)

        display_table_label = _txt(d.get("display_table_label"))
        table_display_name = _txt(d.get("table_display_name"))
        raw_table_name = _txt(d.get("table_name"))

        raw_table_number = d.get("table_number", d.get("table_no", d.get("tableNo")))
        table_number = _int(raw_table_number)
        area_table_number = _int(d.get("area_table_number"))
        area_name = _txt(d.get("area_name", d.get("station_name", "")))

        resolved_table_name = (
            display_table_label
            or table_display_name
            or raw_table_name
        )
        if not resolved_table_name and area_name and area_table_number > 0:
            resolved_table_name = f"{area_name} {area_table_number}".strip()
        if not resolved_table_name and table_number > 0:
            resolved_table_name = f"Masa {table_number}"

        return cls(
            title=_expect_string(
                d.get("title", "MUTFAK SİPARİŞİ"), "title", required=False
            ),
            store_name=_expect_string(
                d.get("store_name", d.get("restaurant_name", "")),
                "store_name",
                required=False,
            ),
            order_no=_expect_string(
                str(d.get("order_no", d.get("order_number", "-"))),
                "order_no",
                required=False,
            ),
            order_number=_txt(d.get("order_number")),
            order_id=_txt(d.get("order_id")),
            daily_order_no=_int(d.get("daily_order_no")),
            kitchen_order_no=_int(d.get("kitchen_order_no")),
            printed_at=printed_at,
            kitchen_printed_at=kitchen_printed_at,
            created_at=created_at,
            order_created_at=order_created_at,
            table_no=_expect_string(
                str(d.get("table_no", d.get("table_number", "-"))),
                "table_no",
                required=False,
            ),
            table_number=table_number,
            area_table_number=area_table_number,
            table_name=_expect_string(resolved_table_name, "table_name", required=False),
            table_display_name=table_display_name,
            display_table_label=display_table_label,
            table_area_name=_expect_string(
                d.get("table_area_name", ""),
                "table_area_name",
                required=False,
            ),
            area_name=_expect_string(
                d.get("area_name", d.get("station_name", "")),
                "area_name",
                required=False,
            ),
            waiter_name=_expect_string(
                d.get("waiter_name", ""), "waiter_name", required=False
            ),
            job_type=_expect_string(
                d.get("job_type", "new_order"), "job_type", required=False
            ),
            date_time=resolved_dt,
            items=items,
        )
