// Generates black-box timestamp expectations using public Go time APIs.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"time"
)

func main() {
	out := []string{}
	for _, s := range []int64{-9223372036854775808, -9223372036854775807, -9223372036854776, -62135596801, -1, 0, 253402300800, 9223372036854776, 9223372036854775807} {
		for _, ns := range []int64{-2147483648, -1000000000, -1, 0, 1, 999999999, 1000000000, 2147483647} {
			t := time.Unix(s, ns).UTC()
			obj := fmt.Sprintf("google.protobuf.Timestamp{seconds:%d,nanos:%d}", s, ns)
			for method, v := range map[string]int{"getFullYear": t.Year(), "getMonth": int(t.Month()) - 1, "getDate": t.Day(), "getDayOfMonth": t.Day() - 1, "getDayOfYear": t.YearDay() - 1, "getDayOfWeek": int(t.Weekday()), "getHours": t.Hour(), "getMinutes": t.Minute(), "getSeconds": t.Second(), "getMilliseconds": t.Nanosecond() / 1000000} {
				out = append(out, fmt.Sprintf("%s.%s() == %d", obj, method, v))
			}
			out = append(out, fmt.Sprintf("int(%s) == %d", obj, t.Unix()), fmt.Sprintf("string(%s) == %q", obj, t.Format(time.RFC3339Nano)))
		}
	}
	sort.Strings(out)
	e := json.NewEncoder(os.Stdout)
	e.SetIndent("", "  ")
	e.SetEscapeHTML(false)
	e.Encode(out)
}
