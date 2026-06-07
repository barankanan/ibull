# Hotfixes - Session Implementation Plan

## Problem 1: Masa Dolu Görünmeme ✅ PARTIAL
**Status**: Optimistic items'ı card'da göstermek eklendi
**Lines Modified**: 11763-11843 in seller_panel_page.dart
**What's Done**:
- `_buildMobileGarsonTableCard` method'u güncellendi: optimisticItems parametresi eklendi
- `from_db` ve `from_optimistic` flags'ler debug log'a eklendi
- CardBuilder'da optimistic items pass ediliyor (line 9175-9188)

**Still Need**:
- activeTableNumbers guarantee etmek (45 saniye timeout değil, infinite olmalı submitted state'i)
- Table card boş masa göstermeme logic'ini garantile

---

## Problem 2: Duplicate Print Jobs
**Status**: Analyzing
**Current State**: 
- `_suppressDuplicateKitchenJobs` function zaten var (line 2680)
- `kitchenPrintIdempotencyKeyFromJob` var
- Dedup logic working for new orders

**Hypothesis**:
- Garson'da "Mutfağa İlet" button'u double-tap koruması yok
- Yada print_station consumer eski job'ı tekrar dispatch'iyor

**Fix Strategy**:
1. Button disable mekanizması ekle (LoadingStateButton)
2. Job claim mekanizmasını güçlendir  
3. Consumer'da completed job check'i zorunlu yap

---

## Problem 3: Terminal-Free Bridge
**Status**: Not started
**Implementation**:
1. Printer center'da Bridge control RPC'si ekle
2. Python server'a bridge start/stop endpoint'i ekle
3. UI'da "Bridge Başlat" button ve status check

---

## Files to Modify:
- [x] ibul_app/lib/screens/seller_panel_page.dart - masa grid (PARTIAL)
- [ ] ibul_app/lib/services/order_print_job_service.dart - button disable
- [ ] ibul_app/lib/screens/seller/printer_system_setup_wizard.dart - terminal-free UI
- [ ] local_print_bridge/server.py - bridge control RPC

---

## Quick Debug Commands:
```bash
# Garson masa test
grep -n "GARSON_TABLE" ibul_app/lib/screens/seller_panel_page.dart

# Duplicate print check
grep -n "KITCHEN_JOB_DEDUP" ibul_app/lib/services/order_print_job_service.dart

# Bridge status check  
curl http://127.0.0.1:3001/health
```
