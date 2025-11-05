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
const re = @import("replace_exe");
// Replace current executable with a new one
try re.selfReplace(allocator, "path/to/new/executable");
// Warning: Deletes current executable
try re.selfDelete();
```
---

### Demo
Two demo applications are provided in the `demo` folder:
`demo.zig` is version 1 and calls `selfReplace` to replace itself with `demo2.zig`

Build the demo applications with:
```sh
zig build -Ddemo
```

Then run the first demo:
```sh
./zig-out/bin/demo
# prints V1
./zig-out/bin/demo
# prints V2
```
This will replace `demo` with `demo2`. You can verify this by running `./demo` again, which will print the version number of `demo2`.

---
### C API
Building the library as a shared object or static library for use with C/C++:
```sh
# This builds a .so shared library like libreplace-exe.so that you can link against
zig build -Dcapi -Dshared -Doptimization=ReleaseFast
# Or if you prefer a static library:
zig build -Dcapi -Doptimization=ReleaseFast
```

This will put the header file `replace_exe.h` and the shared or static library in the `zig-out/include` & `zig-out/lib` folders respectively.

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
