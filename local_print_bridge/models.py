from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal, InvalidOperation
from typing import Any


class PayloadError(ValueError):
    """Raised when an incoming JSON payload is invalid."""


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

    @classmethod
    def from_dict(cls, payload: Any) -> "ReceiptPayload":
        data = _expect_mapping(payload, "payload")
        raw_items = data.get("items")
        if not isinstance(raw_items, list) or not raw_items:
            raise PayloadError("`items` must be a non-empty array.")
        items = [ReceiptItem.from_dict(item) for item in raw_items]
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
            date_time=_parse_datetime(
                data.get(
                    "date_time",
                    data.get("datetime", data.get("printed_at", data.get("dateTime"))),
                )
            ),
            items=items,
            totals=ReceiptTotals.from_payload(data, items=items),
            currency=_expect_string(data.get("currency", "TRY"), "currency"),
            footer_note=_expect_string(
                data.get("footer_note", data.get("footerNote")),
                "footer_note",
                required=False,
            ),
        )
