// Black-box driver for the pinned cel-go interpreter used by OpenFGA v1.22.1.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/google/cel-go/cel"
	"github.com/google/cel-go/checker"
)

type Case struct {
	Expression string         `json:"expression"`
	Context    map[string]any `json:"context"`
	Limit      uint64         `json:"limit"`
	Cancel     bool           `json:"cancel"`
}

type estimator struct{}

func (estimator) EstimateSize(checker.AstNode) *checker.SizeEstimate { return nil }
func (estimator) EstimateCallCost(string, string, *checker.AstNode, []checker.AstNode) *checker.CallEstimate {
	return nil
}

func main() {
	var cases []Case
	if err := json.NewDecoder(os.Stdin).Decode(&cases); err != nil {
		panic(err)
	}
	env, err := cel.NewEnv(cel.Variable("n", cel.IntType), cel.Variable("s", cel.StringType), cel.Variable("t", cel.StringType))
	if err != nil {
		panic(err)
	}
	results := []map[string]any{}
	for _, c := range cases {
		row := map[string]any{}
		ast, issues := env.Compile(c.Expression)
		if issues.Err() != nil {
			row["error"] = issues.Err().Error()
			row["category"] = "compile"
			results = append(results, row)
			continue
		}
		if estimate, e := env.EstimateCost(ast, estimator{}); e == nil {
			row["estimate_min"] = estimate.Min
			row["estimate_max"] = estimate.Max
		}
		prg, e := env.Program(ast, cel.EvalOptions(cel.OptOptimize, cel.OptTrackCost, cel.OptPartialEval), cel.CostLimit(c.Limit), cel.InterruptCheckFrequency(1))
		if e != nil {
			row["error"] = e.Error()
			row["category"] = "compile"
			results = append(results, row)
			continue
		}
		vars := map[string]any{}
		for k, v := range c.Context {
			if k == "n" {
				vars[k] = int64(v.(float64))
			} else {
				vars[k] = v
			}
		}
		ctx, cancel := context.WithCancel(context.Background())
		if c.Cancel {
			cancel()
		}
		activation, e := env.PartialVars(vars)
		if e != nil {
			panic(e)
		}
		value, details, e := prg.ContextEval(ctx, activation)
		cancel()
		if details != nil && details.ActualCost() != nil {
			row["cost"] = *details.ActualCost()
		}
		if e != nil {
			row["error"] = e.Error()
			row["category"] = "evaluation"
		} else {
			row["value"] = fmt.Sprint(value)
			row["value_type"] = value.Type().TypeName()
			row["category"] = "ok"
		}
		results = append(results, row)
	}
	if e := json.NewEncoder(os.Stdout).Encode(results); e != nil {
		panic(e)
	}
}
