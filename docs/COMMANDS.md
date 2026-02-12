# Command Discovery

**TL;DR**: Read the repo's CLAUDE.md/CI configs to find build/test commands. Use those, not hard-coded defaults.

## Discovery Priority

1. **AI instruction files** → CLAUDE.md, .cursorrules, .github/copilot-instructions.md
2. **CI configs** → .github/workflows/*.yml, Makefile, package.json
3. **Language defaults** → Only as fallback

## What to Look For

Search for sections like:
- "Build and Test"
- "Development Commands"
- "Running Tests"
- "CI/CD"

## Extraction Examples

### From CLAUDE.md
```markdown
## Build and Test
- Build: `make build`
- Test: `make test`
```
→ Use `make build`, `make test`

### From .github/workflows/ci.yml
```yaml
- run: go build -tags unit,integration ./...
- run: go test -v ./...
```
→ Use those exact commands

### From package.json
```json
"scripts": {
  "build": "tsc",
  "test": "jest"
}
```
→ Use `npm run build`, `npm test`

## Implementation

```bash
# 1. Check AI instruction files first
BUILD_CMD=$(grep -A 3 "Build:" CLAUDE.md | grep '`' | tr -d '`')

# 2. Fallback to CI config
if [ -z "$BUILD_CMD" ]; then
  BUILD_CMD=$(grep "run:.*build" .github/workflows/*.yml | sed 's/.*run: //')
fi

# 3. Fallback to Makefile/package.json
if [ -z "$BUILD_CMD" ] && [ -f "Makefile" ]; then
  BUILD_CMD="make build"
fi

# 4. Use discovered command
$BUILD_CMD
```

## Language Defaults (Fallback Only)

**Go**: `go build ./...`, `golangci-lint run`, `go test ./...`
**Python**: `python -m compileall .`, `ruff check .`, `pytest`
**JS/TS**: `npm run build`, `npm run lint`, `npm test`
**Rust**: `cargo build`, `cargo clippy`, `cargo test`

Use repo-specific commands when available!
