---
name: kintai-check
description: Check monthly attendance via freee HR API. Fetches work records and all approval request types (work-time corrections, paid holidays, special holidays, overtime), merges them by date, and outputs Markdown tables. Use when the user wants to check attendance (勤怠チェック, 勤怠確認), find missing clock-ins (打刻漏れ), or review the status of any attendance-related request (勤怠修正申請, 有給申請, 特別休暇申請, 残業申請). Supports year/month specification (default is current month).
---

# 勤怠チェックスキル

freee人事労務APIから月次の勤怠実績と各種申請 (勤怠修正・有給・特別休暇・残業) を取得し、日付でマージして表形式で表示するスキル。打刻漏れの発見と申請状況の確認に使う。

重要: 承認待ち (`in_progress`) の申請は勤怠実績 (`work_records`) に反映されない。勤怠修正申請だけを見て「打刻なし = 対応が必要」と判定すると、有給申請などが出ている日を誤って指摘してしまう。必ず全種別を取得して突き合わせること。

## 引数

- `[年 月]` (省略可): 対象年月 (例: `2026 7`)。省略時は今日の日付から当月を使う。
- freee人事労務の「月」は締め期間ベース (例: 7月度 = 6/21〜7/20)。実際の期間はAPIレスポンスの `start_date` / `end_date` で確認すること。

## 手順

### 1. 認証確認

`mcp__freee-mcp__freee_auth_status` を実行する。

- 「有効」→ 次へ進む。
- 「期限切れ」→ そのままAPIを呼ぶと自動更新が試みられる。自動更新も失敗した場合 (`Token refresh failed` / `invalid_grant`) は `mcp__freee-mcp__freee_authenticate` で認証URLを取得してユーザーに提示し、認証完了の連絡を待ってから続行する (URLは5分でタイムアウト)。

### 2. ユーザー情報取得

```
mcp__freee-mcp__freee_api_get
{ "service": "hr", "path": "/api/v1/users/me" }
```

レスポンスの `companies[0].id` を company_id、`companies[0].employee_id` を employee_id として使う。

### 3. 勤怠サマリー取得

```
mcp__freee-mcp__freee_api_get
{
  "service": "hr",
  "path": "/api/v1/employees/{employee_id}/work_record_summaries/{year}/{month}",
  "query": { "company_id": <company_id>, "work_records": true }
}
```

`start_date` / `end_date` が締め期間。`work_records[]` に日別レコードが入る。

### 4. 各種申請の取得 (全種別)

下記4種別をすべて取得する。1メッセージ内で並列に呼ぶこと。

| 種別 | path | レスポンスキー |
|---|---|---|
| 勤怠修正 | `/api/v1/approval_requests/work_times` | `work_times` |
| 有給 | `/api/v1/approval_requests/paid_holidays` | `paid_holidays` |
| 特別休暇 | `/api/v1/approval_requests/special_holidays` | `special_holidays` |
| 残業 | `/api/v1/approval_requests/overtime_works` | `overtime_works` |

クエリは4種別とも共通:

```
mcp__freee-mcp__freee_api_get
{
  "service": "hr",
  "path": <上表のpath>,
  "query": {
    "company_id": <company_id>,
    "start_issue_date": <締め期間開始の約1ヶ月前>,
    "end_issue_date": <今日>,
    "limit": 100
  }
}
```

- 絞り込みは申請日 (`issue_date`) ベースなので広めに取得し、`target_date` が締め期間内のものを抽出する。
- `target_date` が期間外の申請は「期間外の申請」として補足に回す。
- `total_count: 0` の種別は出力に出さない (「特別休暇申請はありません」等の行は不要)。
- 月次勤怠締め申請 (`monthly_attendances`) は対象外。

### 5. マージして表示

`work_records[].date` と全種別の申請の `target_date` を突き合わせ、下記フォーマットで出力する。

## 出力フォーマット

### 1. 月次サマリー表

| 項目 | 値 |
|---|---|
| 労働日数 | `work_days`日 |
| 総労働時間 | `total_work_mins` |
| 所定内労働 | `total_normal_work_mins` |
| 残業 (所定外) | `total_overtime_except_normal_work_mins` |
| 深夜・休日労働 | `total_latenight_work_mins` / `total_holiday_work_mins` |
| 遅刻・早退 | `total_lateness_and_early_leaving_mins` |
| 欠勤 | `num_absences`日 |
| 有給取得 | `num_paid_holidays`日 (取得日を併記) |
| 有給残 | `num_paid_holidays_left`日 |

分の値は「XX時間YY分」に変換する (例: 6932 → 115時間32分)。

### 2. 日別マージ表

```
| 日付 | 区分 | 出勤 | 退勤 | 残業 | 申請 | 申請状況 |
```

- 日付: `M/D (曜)` 形式。
- 区分の判定 (上から順に評価し、最初に当てはまったものを使う):
  1. `clock_in_at` あり → 出勤
  2. `paid_holiday` > 0 → 有給
  3. `special_holiday` > 0 → 特別休暇
  4. `is_absence` が true → 欠勤
  5. `day_pattern` が `normal_day` で上記いずれでもない → その日の申請を見て決める
     - 承認待ちの有給申請あり → 有給 (承認待ち)
     - 承認待ちの特別休暇申請あり → 特別休暇 (承認待ち)
     - 承認待ちの勤怠修正申請あり → 打刻なし (申請中)
     - どの申請もない → 今日なら「打刻なし (今日)」、未来日なら「未到来」、それ以外は「打刻なし」
  6. `day_pattern` が `prescribed_holiday` / `legal_holiday` で打刻なし → 行ごと省略 (表の下に「土日祝は省略」と注記)
- 出勤・退勤: `HH:MM`。残業: `total_overtime_work_mins` を「XX分」で。
- 申請セルの書式 (種別ごと)。申請なしは `—`:
  - 勤怠修正: `#<application_number> 勤怠修正: HH:MM〜HH:MM (休憩HH:MM〜HH:MM)`
  - 有給: `#<application_number> 有給: <holiday_type>` — full=全日 / am=午前半休 / pm=午後半休。時間単位のときは `start_at`〜`end_at` を併記する
  - 特別休暇: `#<application_number> 特別休暇: <レスポンスの休暇種別>`
  - 残業: `#<application_number> 残業申請`
  - 同じ日に複数の申請がある場合は `<br>` 区切りで併記する
- 特別休暇・残業の申請はレスポンス実物を見て表示する。上記以外のフィールドを決め打ちしないこと。
- 申請状況のマッピング: draft=下書き, in_progress=承認待ち, approved=承認済み, rejected=却下, feedback=差戻し。

### 3. 補足

- 承認待ち申請の一覧表 (種別、`#番号`、対象日、申請日、コメント、承認後の反映内容)。種別を必ず併記する。
- 要対応の指摘。ただし以下をすべて満たす日だけに限定する:
  - 過去日 (今日より前)
  - `day_pattern` が `normal_day`
  - 打刻・有給・特別休暇・欠勤のいずれもなし
  - どの種別の申請も出ていない (承認待ちを含む)
- 承認待ちの有給・特別休暇申請がある場合、`num_paid_holidays_left` にはまだ反映されていない旨を注記する (承認後に残日数が減ることを明示)。
- 期間外の申請一覧 (種別、`#番号`、対象日、状況)。

## エラーハンドリング

- トークン失効 + 自動リフレッシュ失敗 → 手順1の再認証フロー。
- 指定月のデータがない (未来月など) → その旨を表示して終了。
- 手順4でいずれかの種別が 403 (`access_denied`) を返した場合 → その種別だけスキップし、出力末尾に「<種別>申請は権限不足で未取得」と注記して処理を続行する。全体は中断しない。

## 使用場面

- 月次の勤怠締め前チェック (打刻漏れ・申請漏れの確認)
- 各種申請 (勤怠修正・有給・特別休暇・残業) の承認状況の確認
- 残業時間・有給残数の確認
