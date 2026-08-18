---
description: GitHub Project のアイテム一覧を Markdown タスクリストとして出力する。
---

引数「$ARGUMENTS」を解析してください：
- 形式: <オーナー名> <プロジェクト番号>
- 例: yuu 1

## 実行手順

1. マッピングデータを読み込む：

```bash
cat ~/.cache/agent-command/project-list.json 2>/dev/null || echo '{}'
```

`{}` が返った場合(ファイル未配置)はマッピング定義なしとして扱い、そのまま手順2へ進む。

2. 以下の2つのコマンドを `|` で繋いで実行：

```bash
gh project item-list <プロジェクト番号> --owner <オーナー名> --format json -L 100
```

```bash
jq '{
  estimates: [.items[] | select(
    (((.labels // []) | any(test("Proposal"; "i"))) or (.title | test("見積")))
    and (.status != "Abandoned")
  ) | {
    title: .title,
    status: .status,
    repository: .repository,
    priority: .priority,
    labels: (.labels // []),
    label_type: ((.labels // []) | map(select(startswith("Type: "))) | first // null),
    type: .content.type
  }] | sort_by(.repository // "zzz") | group_by(.repository),
  items: [.items[] | select(
    ((((.labels // []) | any(test("Proposal"; "i"))) or (.title | test("見積"))) | not)
    and (.status != "Abandoned")
  ) | {
    title: .title,
    status: .status,
    repository: .repository,
    priority: .priority,
    labels: (.labels // []),
    label_type: ((.labels // []) | map(select(startswith("Type: "))) | first // null),
    type: .content.type,
    iteration_title: .iteration.title,
    iteration_start: .iteration.startDate
  }] | sort_by(
    .iteration_start // "9999-99-99",
    .repository // "zzz",
    (if .status == null then 0 elif .status == "In Progress" or .status == "Todo" then 1 else 2 end),
    (if .type == "Issue" then 0 elif .type == "DraftIssue" then 1 else 2 end)
  ) | group_by(.iteration_start) | map(group_by(.repository))
}'
```

3. 以下のテンプレートに従って Bash で `mkdir -p ~/.cache/task` してから `>| ~/.cache/task/task.md` にリダイレクトして強制上書き出力：

**マッピングデータ (`~/.cache/agent-command/project-list.json`)：**

| キー | 内容 |
|------|------|
| `repositories.<repository>.display` | リポジトリ表示名 |
| `repositories.<repository>.company` | 会社略称 |
| `priorities.<priority>` | priority の表示文字列 |

- `<repository>` は GitHub Project の `repository` フィールドの URL 末尾
- `repositories` に定義がない repository は、repository 名をそのまま表示名として使う(会社略称なし)
- `repository` が null のアイテムは `DraftIssue` として扱う
- `priorities` に定義がない priority はその値をそのまま表示
- JSON が未配置(`{}`)の場合はマッピングを行わず、repository 名と priority 値をそのまま表示する。エラーとして中断しない

サンプルは `project-list.example.json` を参照。

**出力テンプレート：**

見積・提案セクション（`estimates` 配列、アイテムがある場合のみ出力）：
会社略称でグルーピングする(表示名の先頭が同じ会社略称のリポジトリをまとめる)
```markdown
# 見積・提案

## {会社略称}
- [ ] {タイトル} `{priority}`

---
```

Backlog（iteration_start が null）の場合：
```markdown
# {リポジトリ表示名}

### {label_type から "Type: " を除いた値}
- [ ] {タイトル} `{priority}`

### その他
- [ ] {label_typeがないIssue/DraftIssue}

## Pull Requests
- [x] {PRのタイトル}

---
```

Iteration がある場合：
```markdown
# {iteration_title}

## {リポジトリ表示名}
- [x] {タイトル} `{priority}`

---
```

**ルール：**
- `estimates` に該当するアイテムは **最初に「# 見積・提案」セクション** として出力し、`items` 側には含めない
- status が Done → `[x]`、それ以外 → `[ ]`
- priority は `priorities` マッピングに従い `P-High` 等の形式で表示。存在する場合のみ末尾に追加
- Issue/DraftIssue は `label_type` でグルーピングし `### {Type名}` で小見出しにする。表示順は Bug → Feature → Improve → Question → その他(label_typeなし)
- `### {Type名}` のグルーピングは該当するアイテムがある場合のみ出力
- `PullRequest` は `## Pull Requests` セクションにまとめる(PR がある場合のみ出力)
- リポジトリ間・Iteration 間は `---` で区切る
