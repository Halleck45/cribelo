# Contributing

Most of the work happens in [AST Metrics](https://github.com/ast-metrics/ast-metrics). The code of Cribelo lives there, in the `cribelo` and `internal/cribelo` directories, next to the parsers, the complexity model and the dependency graph it relies on. A change to the ranking, the signals, the plan or the supported languages is a pull request on AST Metrics, and its [contributing guide](https://github.com/ast-metrics/ast-metrics/blob/main/.github/CONTRIBUTING.md) explains how to build it, run the tests and find your way in the code.

This repository holds what ships Cribelo: the GitHub Action, the installer, the release workflow, the Homebrew formula and the documentation. Pull requests on those are welcome here. A change merged in AST Metrics reaches Cribelo when the revision pinned in `go.mod` is bumped:

```sh
go get github.com/ast-metrics/ast-metrics@<commit>
go mod tidy
CGO_ENABLED=1 go build -o cribelo .
scripts/smoke-test.sh ./cribelo
```

The build needs a C compiler for the tree-sitter parsers. The smoke test runs the binary on a throwaway repository with one change per supported language and checks what it measures: the complexity of each change, the order of the plan, the options (`--top`, `--budget`, `-C`, `--no-clones`, `--no-color`, `--fail-on`, `--weights`), `.cribelo.yaml`, the three formats, `skip` and `explain`. It then generates a history of forty changes to run `backtest` and `calibrate`. It needs git, bash and Python 3, and takes a few seconds. The CI runs the same build and test on Linux, macOS and Windows for every pull request, so a bump that loses a parser or breaks a platform fails before the release.

Open issues here, whatever part of the code they concern. If a file is ranked oddly, paste the output of `cribelo explain` for that file.
