# Gmail本文からGoogle Calendarリンクを生成

以下のメール本文から予定情報を抽出し、Google Calendarの予定作成リンクを生成してください。

## 抽出する情報
- **イベント名**: サロン名、店舗名、イベント名など
- **開始日時**: 日付と時刻
- **終了日時**: 施術時間や所要時間から計算（不明な場合は1時間後）
- **場所**: 住所、Google Maps URL、座標など
- **詳細**: 予約番号、電話番号、金額など重要な情報

## 出力形式

1. 抽出した情報を表形式で表示
2. Google Calendarリンクを生成（URLエンコード済み）
3. クリック可能なMarkdownリンクも提供

## リンク形式
```
https://calendar.google.com/calendar/render?action=TEMPLATE&text=イベント名&dates=YYYYMMDDTHHmmssZ/YYYYMMDDTHHmmssZ&details=詳細&location=場所
```

※日時はUTC形式に変換すること（日本時間から-9時間）

---

## メール本文

$ARGUMENTS
