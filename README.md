# replace-exe

A smol Zig library that lets a running executable replace (or delete) itself.

This can be used, for instance, in applications implementing a self update feature keeping the current installation path intact.

Only windows, linux, and unix like systems (macOS, *BSD) are supported.

---
### Usage
1. Add the library to your **build.zig.zon**:
```zsh
zig fetch --save git+https://github.com/weezy20/replace-exe.git
```

2. Add it to your **build.zig**:
```zig
const exe = b.addExecutable(.{
    ...
});

// Add the replace_exe dependency
const libreplace_exe = b.dependency("replace_exe", .{});
exe.root_module.addImport("replace_exe", libreplace_exe.module("replace_exe"));
```

3. Call `selfReplace` or `selfDelete` from your code:
```zig
// step 1: import
const re = @import("replace_exe");
// step 2: register hook as soon as possible in main(). This is a no-op on non-windows:
pub fn main() !void {
    re.registerHooks(allocator); // or re.registerHooks(null) if you want to go with the default ArenaAllocator(std.heap.page_allocator) for `selfDeleteInit()` operations
    // your logic here..
}
// Replace current executable with a new one
try re.selfReplace(allocator, "path/to/new/executable");
// Warning: Deletes current executable
try re.selfDelete();
```
---

### Demo
Some example code is provided in the [demo](demo) folder:
[demo.zig](demo/demo.zig) is an application that calls `selfReplace` to replace itself with the updated version [demo2.zig](demo/demo2.zig)

Build the demo applications with:
```sh
zig build -Ddemo
```

Then run the first demo exe:
```sh
./zig-out/bin/demo delete # self-delete
./zig-out/bin/demo replace ?</path/to/new/exe> # self-replace; default path is ./zig-out/bin/demo2
```

---
### FFI via C ABI
If you're using it via FFI, the function signatures are defined in [replace_exe.h](include/replace_exe.h) and can be used in your code as the following:
- `selfReplace` becomes `self_replace(const char* path)`
- `selfDelete` becomes `self_delete()`
- `registerHooks(?std.mem.Allocator)` becomes `register_hooks()`

See [c_api.zig](c_api.zig) for definitions. 
Building the library as a shared object or static library for use with C/C++:

Building:
```sh
# This builds a .so shared library like libreplace-exe.so that you can link against
zig build -Dcapi -Dso -Doptimization=ReleaseFast
# Or if you prefer a static library:
zig build -Dcapi -Doptimization=ReleaseFast
```
Example usage in C (using dynamic library): See [demo.c](demo/demo.c)

1. Build your C app using either of the generated libraries:
```sh
gcc demo/demo.c -Izig-out/include -Lzig-out/lib -lreplace-exe -o test
```
2. Run the C demo:
```sh
LD_LIBRARY_PATH=zig-out/lib ./test /path/to/new/executable
```
3. Run again to verify replacement:
```sh
LD_LIBRARY_PATH=zig-out/lib ./test
```

Or if you prefer go (using `cgo`): See [demo/main.go](demo/main.go) for an example.
1. Build your Go app linking `libreplace-exe.a` or `libreplace-exe.so`:
```sh
go build -o demo-go demo/main.go
```
2. Run the Go demo:
```sh
./demo-go replace /path/to/new/executable
```
