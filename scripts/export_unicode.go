// Export public unicode API data, not Go or RE2 implementation code.
package main
import("encoding/json";"os";"unicode")
func main(){
 tables:=map[string][][2]int{}
 for name,t:=range unicode.Categories { for r:=rune(0);r<=unicode.MaxRune;r++ { if unicode.Is(t,r) { xs:=tables[name];if len(xs)>0 && xs[len(xs)-1][1]+1==int(r){xs[len(xs)-1][1]=int(r)}else{xs=append(xs,[2]int{int(r),int(r)})};tables[name]=xs } } }
 for name,t:=range unicode.Scripts { for r:=rune(0);r<=unicode.MaxRune;r++ { if unicode.Is(t,r) { xs:=tables[name];if len(xs)>0 && xs[len(xs)-1][1]+1==int(r){xs[len(xs)-1][1]=int(r)}else{xs=append(xs,[2]int{int(r),int(r)})};tables[name]=xs } } }
 folds:=map[rune]rune{}
 for r:=rune(0);r<=unicode.MaxRune;r++ { min:=r;for x:=unicode.SimpleFold(r);x!=r;x=unicode.SimpleFold(x){if x<min{min=x}};if min!=r{folds[r]=min} }
 json.NewEncoder(os.Stdout).Encode(struct{Version string; Tables map[string][][2]int; Folds map[rune]rune}{unicode.Version,tables,folds})
}
