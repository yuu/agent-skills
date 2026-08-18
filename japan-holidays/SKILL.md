---
name: jp-holidays
description: Get Japan's national holidays from the Cabinet Office. Use this skill when you need to retrieve Japanese holiday information. Supports year specification (default is current year). Outputs in Markdown table format.
---

# Japan Holidays Skill

日本の祝日を取得するスキルです。内閣府が提供する祝日データを取得します。

このスキルは、日本の祝日情報が必要な場合に使用します。

## サポートプラットフォーム

- **macOS**: curl コマンド
- **Linux**: curl コマンド
- **Windows**: Git Bash/MSYS2/Cygwin の curl コマンド

## 使用方法

```bash
bash scripts/get-holidays.sh [年]
```

### パラメータ

- **年**（省略可）: 取得する年を指定（省略時は今年）

### 使用例

#### 今年の祝日を取得

```bash
bash scripts/get-holidays.sh
```

#### 特定の年の祝日を取得

```bash
bash scripts/get-holidays.sh 2026
```

## 出力フォーマット

Markdown テーブル形式で出力されます：

```markdown
# 日本の祝日 (2025年)

| 日付 | 祝日名 |
|------|--------|
| 2025-01-01 | 元日 |
| 2025-01-13 | 成人の日 |
| 2025-02-11 | 建国記念の日 |
...
```

## AI エージェントからの使用方法

AI エージェント（Claude Code など）がこのスキルを使用する場合、以下のように実行します：

### 基本的な使用

1. 今年の祝日が必要な場合
2. Bash ツールでスクリプトを実行：
   ```bash
   bash scripts/get-holidays.sh
   ```

### 特定の年の祝日を取得

1. 過去または未来の祝日が必要な場合
2. Bash ツールでスクリプトを実行：
   ```bash
   bash scripts/get-holidays.sh 2026
   ```

## 使用場面

- **スケジュール管理**: カレンダーアプリケーションの祝日表示
- **日付計算**: 営業日計算や納期計算
- **イベント計画**: 祝日を考慮したイベント日程の提案
- **情報提供**: ユーザーへの祝日情報の提示
- **ドキュメント生成**: 年間カレンダーやスケジュール表の作成

## データソース

- **提供元**: 内閣府
- **URL**: https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv
- **ライセンス**: CC-BY（クリエイティブ・コモンズ 表示）
- **更新頻度**: 内閣府が随時更新

## エラーハンドリング

### ネットワークエラー

```
エラー: 祝日データの取得に失敗しました
```

→ ネットワーク接続を確認してください。

### 無効な年の指定

```
エラー: 年は 4 桁の数値で指定してください
```

→ 正しい年（例: 2025）を指定してください。

## 技術詳細

- **実装言語**: Bash スクリプト
- **依存ツール**: curl, awk, date
- **データ形式**: CSV（Shift_JIS エンコード）
- **出力形式**: Markdown テーブル

## 注意事項

- このスキルはネットワーク接続が必要です
- データは毎回取得されます（キャッシュなし）
- 内閣府のサーバーがダウンしている場合は取得できません
- CSV データは Shift_JIS でエンコードされています

## 参考リンク

- [内閣府 - 「国民の祝日」について](https://www8.cao.go.jp/chosei/shukujitsu/gaiyou.html)
- [政府統計の総合窓口（e-Stat）](https://www.e-stat.go.jp/)
- [デジタル庁 - data.go.jp](https://data.e-gov.go.jp/)
