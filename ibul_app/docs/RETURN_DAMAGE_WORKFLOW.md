# Return + Damage Workflow

## 1) Database Setup
Run this SQL in Supabase SQL Editor:

- `SUPABASE_RETURN_DAMAGE_WORKFLOW.sql`

This creates:
- `public.order_item_return_requests`
- `public.ihiz_return_pickup_tasks`
- `return-evidence` storage bucket
- required RLS policies and update triggers

## 2) Mobile/User Flow (Order Detail)
Implemented in:
- `lib/screens/order_detail_page.dart`

### A) Create return request with damage evidence
UI action:
- `Iade Talebi` button (delivered items)

Backend call:
- `OrderService.submitReturnRequest(...)`

Data sent:
- reason
- issue tags
- customer detail
- damage level + damage description
- evidence images (up to 3)

What happens backend-side:
- uploads images to `return-evidence`
- inserts row into `order_item_return_requests` with `pending_seller_review`
- updates `order_items.status = return_requested`
- writes status history
- sends user + seller notification

### B) Buyer pickup scheduling after seller approval
UI action:
- `Kurye Zamanı Seç` button (when item status is `return_approved`)

Backend call:
- `OrderService.scheduleReturnPickupWindow(...)`

What happens backend-side:
- updates return request to `pickup_scheduled`
- writes pickup window and buyer note
- creates courier task in `ihiz_return_pickup_tasks`
- writes tracking history event
- sends buyer + seller notifications

## 3) Seller Flow (Seller Panel)
Implemented in:
- `lib/screens/seller_panel_page.dart`

UI action:
- In order actions, `İade Talebini İncele`

Backend call:
- `OrderService.sellerReviewReturnRequest(...)`

Decisions:
- `approve` -> return request `awaiting_customer_pickup_slot`, item status `return_approved`
- `reject` -> return request `rejected_by_seller`, item status `delivered`
- `report_to_ibul` -> return request `reported_to_ibul`, item stays return flow, admin notifications generated

Extra seller actions:
- `return_shipped_back` -> `return_received`
- `return_received` -> `refunded`

## 4) İBUL/Admin Resolution API
Service method added:
- `OrderService.resolveReportedReturnByIbul(...)`

Usage:
- accept seller rejection -> close case, item back to delivered
- reject seller rejection -> reopen flow, item to return_approved

## 5) Service Methods Added
Implemented in:
- `lib/services/order_service.dart`

New methods:
- `submitReturnRequest(...)` (extended)
- `getLatestReturnRequestForItem(...)`
- `sellerReviewReturnRequest(...)`
- `scheduleReturnPickupWindow(...)`
- `resolveReportedReturnByIbul(...)`

Internal helpers:
- evidence image upload to Supabase Storage
- admin notification generation for reported cases
