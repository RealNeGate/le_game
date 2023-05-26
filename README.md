# Le Game

This is a tiny Luajit+Cuik demo, as long as the cuik.dll is in your path you can do:

```
luajit main.lua
```

and see some little square guy with an orbiter square. We're dealing with platform layer stuff
in dynamically compiled C code which interfaces relatively seamlessly with Luajit's FFI. My plan
is to finish this demo and add support for recent versions of PUC Lua.
