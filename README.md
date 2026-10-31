# MoonFGA

MoonFGA is an OpenFGA-compatible relationship-based authorization (ReBAC)
engine written in MoonBit. It implements the OpenFGA schema 1.1 modeling
language, JSON authorization models, tuple storage, `Check`, `BatchCheck`,
`ListObjects`, `ListUsers`, `Expand`, and a CEL subset for conditional
relationships. The library runs on the native, wasm-gc and JavaScript
backends, so the same model can be used on a server, at the edge, or in a
browser.

"OpenFGA" is a trademark of the OpenFGA project. MoonFGA is an independent
implementation and is not endorsed by the OpenFGA project.

See `docs/conformance.md` for the upstream test matrix results and
`docs/proposal.md` for the hackathon submission summary.
