import csv

# Backup'tan oku (orijinal CSV)
with open('urun_sablonu.csv.backup', 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    rows = list(reader)

# Yeni CSV'yi yaz - tam olarak 21 field garantili
with open('urun_sablonu.csv', 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    for i, row in enumerate(rows, 1):
        # Keyword field (index 13) - virgülleri pipe'a çevir
        if len(row) >= 14:
            row[13] = row[13].replace(',', '|')
        
        # Hasarlı parça field (index 15) - virgülleri pipe'a çevir
        if len(row) >= 16:
            row[15] = row[15].replace(',', '|')
        
        # Tam olarak 21 field olmalı
        if len(row) < 21:
            # Eksik field'ları boş string olarak ekle
            row.extend([''] * (21 - len(row)))
        elif len(row) > 21:
            # Fazla field'ları kaldır (son field'lar boş olmalı)
            row = row[:21]
        
        writer.writerow(row)

print(f"CSV düzeltildi. Toplam {len(rows)} satır işlendi.")
print(f"Tüm satırlar artık tam olarak 21 field'a sahip.")
