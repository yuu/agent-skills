---
name: kintai-fix
description: Submit a work-time correction request (勤怠修正申請) via freee HR API. Use when the user wants to fix a missing clock-in/out (打刻漏れ) by submitting an approval request for a specific date. Confirms content with the user before submitting. Defaults to 08:00-17:00 with a 12:00-13:00 break.
---

# 勤怠修正申請スキル

freee人事労務APIで勤怠修正申請 (work_times) を送信するスキル。打刻漏れの日に対して、内容確認のうえ承認申請をPOSTする。打刻漏れの発見には kintai-check スキルを使う。

## 引数

- `<対象日>` (必須): 例 `7/10`, `2026-07-10`。複数日指定も可 (1日ずつPOSTする)。
- 時刻・コメント (省略可)。省略時のデフォルト:
  - 出勤 08:00 / 退勤 17:00 / 休憩 12:00〜13:00
  - コメント「すみません押し忘れました」

## 手順

### 1. 認証確認

`mcp__freee-mcp__freee_auth_status` を実行。失効かつ自動リフレッシュ失敗 (`invalid_grant`) の場合は `mcp__freee-mcp__freee_authenticate` で認証URLを提示し、ユーザーの完了連絡を待つ。

### 2. company_id の確認

セッション内で未取得なら `hr` の `/api/v1/users/me` から `companies[0].id` を取得。

### 3. 申請内容の確認 (必須)

送信前に AskUserQuestion で対象日・時刻・コメントをユーザーに確認する。承認者に通知が飛ぶ外部アクションのため、確認なしで送信しないこと。

### 4. approval_flow_route_id の取得

承認経路一覧 (`/api/v1/approval_flow_routes`) はこのアプリでは権限がなく403になるため、直近の申請から動的に取得する:

1. `GET /api/v1/approval_requests/work_times` (query: `company_id`, `start_issue_date`=2ヶ月前, `end_issue_date`=今日, `limit`: 5) で直近の申請IDを得る
2. `GET /api/v1/approval_requests/work_times/{id}` (query: `company_id`) で `approval_flow_route_id` と `approver_ids` を得る

参考 (2026-07時点の値、必ず動的取得で上書き): route 1082923 (IcT部申請) / approver 2422765。

### 5. 申請のPOST

```
mcp__freee-mcp__freee_api_post
{
  "service": "hr",
  "path": "/api/v1/approval_requests/work_times",
  "body": {
    "company_id": <company_id>,
    "target_date": "YYYY-MM-DD",
    "work_records": [{"clock_in_at": "HH:MM", "clock_out_at": "HH:MM"}],
    "break_records": [{"clock_in_at": "HH:MM", "clock_out_at": "HH:MM"}],
    "comment": "<コメント>",
    "approval_flow_route_id": <route_id>,
    "approver_id": <approver_id>
  }
}
```

注意: 打刻時刻はトップレベルの `clock_in_at` / `clock_out_at` ではなく `work_records` 配列で渡す。トップレベルだけだと 400「clear_work_timeを指定していない時は、work_recordsが必須です」になる。

打刻の取消を申請したい場合は `clear_work_time: true` を指定する (`work_records` 不要)。

### 6. 結果報告

レスポンスから以下を表示する:

- 申請番号 `application_number` と ID
- 対象日・時刻・休憩・コメント
- 承認経路 `approval_flow_route_name`、状況 (`in_progress` = 承認待ち)、`passed_auto_check`

## エラーハンドリング (実例ベース)

- 403 access_denied「このアプリケーションにはアクセス権限がないエンドポイントです」
  - レートリミットではなくアプリの権限不足。freee developers (https://app.secure.freee.co.jp/developers/applications) で人事労務の各種申請 (承認申請) に更新権限を付与してもらう
  - 権限変更後はトークン再取得が必要: `freee_clear_auth` → `freee_authenticate` → ユーザーが認証 → 再送
- 400「approval_flow_route_id が指定されていません」→ 手順4で経路IDを取得して付与する
- 400「clear_work_timeを指定していない時は、work_recordsが必須です」→ `work_records` 配列で送る
- 認証URLは5分でタイムアウト。切れたら `freee_authenticate` を再実行する

## 使用場面

- kintai-check で見つけた打刻漏れの修正申請
- 打刻ミスの取消申請 (`clear_work_time: true`)
