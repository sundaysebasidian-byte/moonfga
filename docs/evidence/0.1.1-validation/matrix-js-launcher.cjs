// The existing conformance CLI consumes native-style argv (one prefix).
// Normalize Node's two-prefix argv for this engine matrix run.
process.argv = [process.execPath];
require(process.cwd() + '/_build/js/debug/build/cmd/conformance/conformance.js');
