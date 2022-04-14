# nyancore
Small lib for my personal projects

used in [lamia](https://github.com/Black-Cat/lamia) sdf editor

# Awesome libs used in this project

* Dear ImGUI (with cImGui interface)
* enet
* glfw
* glslang
* vulkan-zig
* tracy

Math implementation is based on cglm implementation

## Tracing

If you have enabled tracing, add zone tracing code
```zig
const tracy = @import("tracy.zig");

var zone: tracy.Zone = tracy.Zone.start_color_from_file(@src(), null);
defer zone.end();
```

Different start functions control how color for zone is choosen. You can choose your own with `0xRRGGBB`
Frames are automaticaly traced in `Application` main loop

Use tracy v0.8 to connect to application

