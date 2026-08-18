#!/usr/bin/env bash
# Get Japan's national holidays from the Cabinet Office
# Supports year specification (default is current year)

# デフォルト値: 今年
DEFAULT_YEAR=$(date '+%Y')

# 引数の取得
YEAR="${1:-$DEFAULT_YEAR}"

# 年の形式チェック（4桁の数値）
if ! [[ "$YEAR" =~ ^[0-9]{4}$ ]]; then
    echo "エラー: 年は 4 桁の数値で指定してください（例: 2025）" >&2
    exit 1
fi

# 祝日 CSV の URL
CSV_URL="https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv"

# CSV を取得
CSV_DATA=$(curl -sS "$CSV_URL")

# curl の終了ステータスをチェック
if [ $? -ne 0 ] || [ -z "$CSV_DATA" ]; then
    echo "エラー: 祝日データの取得に失敗しました" >&2
    echo "URL: $CSV_URL" >&2
    exit 1
fi

# プラットフォームの検出
detect_platform() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

PLATFORM=$(detect_platform)

# CSV を UTF-8 に変換（元データは Shift_JIS）
case "$PLATFORM" in
    macos)
        # macOS の iconv
        CSV_UTF8=$(echo "$CSV_DATA" | iconv -f SHIFT_JIS -t UTF-8 2>/dev/null)
        ;;
    linux|windows)
        # Linux/Windows の iconv
        CSV_UTF8=$(echo "$CSV_DATA" | iconv -f SHIFT_JIS -t UTF-8 2>/dev/null)
        ;;
    *)
        # iconv が使えない場合はそのまま使用
        CSV_UTF8="$CSV_DATA"
        ;;
esac

# 変換に失敗した場合は元データを使用
if [ -z "$CSV_UTF8" ]; then
    CSV_UTF8="$CSV_DATA"
fi

# 指定された年の祝日をフィルタリング
# CSV フォーマット: 日付（YYYY/MM/DD）,祝日名
# 1行目はヘッダーなのでスキップ
HOLIDAYS=$(echo "$CSV_UTF8" | awk -F',' -v year="$YEAR" '
    NR > 1 {
        # 日付を取得
        date = $1
        # 祝日名を取得（先頭の空白を削除）
        gsub(/^[ \t]+/, "", $2)
        name = $2

        # 年でフィルタリング
        if (date ~ "^" year "/") {
            # 日付を YYYY/MM/DD から年月日に分割
            split(date, parts, "/")
            y = parts[1]
            m = parts[2]
            d = parts[3]

            # 月と日を0埋め（2桁）
            if (length(m) == 1) m = "0" m
            if (length(d) == 1) d = "0" d

            # YYYY-MM-DD 形式に再構築
            formatted_date = y "-" m "-" d
            print formatted_date "|" name
        }
    }
')

# 祝日が見つからなかった場合
if [ -z "$HOLIDAYS" ]; then
    echo "# 日本の祝日 (${YEAR}年)"
    echo ""
    echo "指定された年の祝日データが見つかりませんでした。"
    exit 0
fi

# Markdown テーブル形式で出力
echo "# 日本の祝日 (${YEAR}年)"
echo ""
echo "| 日付 | 祝日名 |"
echo "|------|--------|"

# 祝日を1行ずつ出力
echo "$HOLIDAYS" | while IFS='|' read -r date name; do
    echo "| $date | $name |"
done

exit 0
