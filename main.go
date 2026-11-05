// Command cribelo tells which files of a change are worth a human reader.
//
// The analysis lives in github.com/ast-metrics/ast-metrics; this module pins
// a revision of it in go.mod and builds the released binary.
package main

import (
	"os"
	"runtime/debug"
	"strings"

	"github.com/ast-metrics/ast-metrics/cribelo"
)

// version is set at release time with -ldflags "-X main.version=1.2.3". A
// `go install` build has no ldflags and takes the module version instead.
var version = ""

func main() {
	os.Exit(cribelo.Run(os.Args, fullVersion()))
}

// fullVersion is "1.2.3 (engine a1b2c3d)": the release of Cribelo, then the
// revision of AST Metrics it was built with, a tag or the commit of a
// pseudo-version.
func fullVersion() string {
	v := version
	info, ok := debug.ReadBuildInfo()
	if v == "" && ok && info.Main.Version != "" && info.Main.Version != "(devel)" {
		v = strings.TrimPrefix(info.Main.Version, "v")
		if strings.HasPrefix(v, "0.0.0-") {
			v = "" // an untagged checkout, not a release
		}
	}
	if v == "" {
		v = "dev"
	}
	if !ok {
		return v
	}
	for _, dep := range info.Deps {
		if dep.Path != "github.com/ast-metrics/ast-metrics" {
			continue
		}
		engine := dep.Version
		if i := strings.LastIndex(engine, "-"); i >= 0 && strings.Count(engine, "-") >= 2 {
			engine = engine[i+1:] // pseudo-version: keep the commit
		}
		return v + " (engine " + engine + ")"
	}
	return v
}
