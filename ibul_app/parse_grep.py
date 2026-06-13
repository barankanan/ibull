import re

with open("grep_results.txt", "r") as f:
    lines = f.readlines()

conscious = []
refactored = []
problematic = []

for line in lines:
    lower_line = line.lower()
    
    # Exclude files that are not dart or sql
    if ".dart:" not in line and ".sql:" not in line and ".yaml:" not in line and ".json:" not in line:
        continue
        
    # Conscious ones:
    # SQL literal uses (we said this is out of scope for now, DB literal is conscious)
    if ".sql:" in line:
        conscious.append(line)
        continue
    
    # test files where we explicitly test strings
    if "test/" in line:
        conscious.append(line)
        continue
    
    # Refactored ones (uses OrderStatusConstants or terminalStatuses)
    if "OrderStatusConstants" in line or "terminalStatuses" in line or "cancelledStatuses" in line or "completedStatuses" in line:
        refactored.append(line)
        continue
        
    # Variables or fields like isClosed, deliveredAt
    if re.search(r'\b(is_?closed|delivered_?at|completed_?at|closed_?at|paid_?amount)\b', lower_line):
        conscious.append(line)
        continue
        
    # Rest might be problem areas
    # Only if it's actually matching a string literal 'delivered' or "delivered" or == delivered
    if re.search(r"['\"](delivered|completed|cancelled|refunded|returned|rejected|confirmed|shipped|in_transit|closed|served|paid)['\"]", lower_line):
        problematic.append(line)
    else:
        # Not a string literal, probably variable name
        pass

print(f"Bilinçli (SQL/Test/DB alanları): {len(conscious)}")
print(f"Refactor edilmiş (Constant kullanan): {len(refactored)}")
print(f"Problemli (Hâlâ literal kullanan Dart dosyaları): {len(problematic)}")

if len(problematic) > 0:
    print("\nİlk 10 problemli satır:")
    for l in problematic[:10]:
        print(l.strip()[:150])


print("\nProblemli listesi:")
for l in problematic:
    if "lib/ads/" not in l and "lib/features/admin" not in l and "test/" not in l:
        print(l.strip())
