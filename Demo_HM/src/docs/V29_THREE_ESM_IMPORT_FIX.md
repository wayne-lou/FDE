# V29 Three.js ESM Import Fix

Fixes Hologram Agent GLB loading error:

`The specifier “three” was a bare specifier, but was not remapped to anything.`

Changed Three.js imports from jsDelivr examples module to esm.sh rewritten ESM imports:

- `https://esm.sh/three@0.160.0`
- `https://esm.sh/three@0.160.0/examples/jsm/loaders/GLTFLoader.js`

Also bumped `index.cfm` script cache version to `app.js?v=29`.
