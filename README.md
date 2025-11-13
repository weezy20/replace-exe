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
// step 2: register hook as soon as possible in main(). This is a no-op on non-windows OS:
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    // CRITICAL (windows): Call init() BEFORE any application logic.
    // On Windows, this detects if the process is a cleanup helper and exits immediately.
    // Any code before this line will run in helper processes too if spawned using selfDelete or selfReplace in windows!
    re.init(allocator); // or re.init(null) if you want to go with the default ArenaAllocator(std.heap.page_allocator) for `selfDeleteInit()` operations
    // your logic here..
}
// Replace current executable with a new one
try re.selfReplace(allocator, "path/to/new/executable");
// Warning: Deletes current executable
try re.selfDelete();
```


Note: On windows, if you're deleting the parent folder itself of the current exe itself then you might not want to use `selfDelete` directly but instead provide the current parent dir (or really any dir that you want to prevent from being locked) using `selfDeleteExcludingPath(path: []const u8)` where the function ensures that no temporary exes are put into that path, thereby preventing its deletion for the lifetime of the current running executable.

The current strategy is to place temporary exes in `%TMP%` or `%TEMP%` & if that fails due to cross filesystem paths (exe & temp dir being on different filesystems) we fallback to storing the temp exe helpers in current parent of running exe unless `selfDeleteExcludingPath(p)` is provided in which case, the parent of `p` would be selected & as a fallback, we would go back to using the same parent dir of current-exe.

> Recommended guidelines:

> - Call these functions at most once each per program execution
> - (UNSAFE windows) If using both, prefer do selfReplace before selfDelete - This will still not cleanup the helpers properly as the original file would've been moved & will spawn the new/exe/ which my not have
> the call to `init()` thereby preventing self-cleanup. It's best to avoid this.
> - Ideally, make them mutually exclusive in your application logic

---

### Demo
Some example code is provided in the [demo](demo) folder:
[demo.zig](demo/demo.zig) is an application that calls `selfReplace` to replace itself with the updated version [demo2.zig](demo/demo2.zig)

Build the demo applications with:
```sh
# Build zig demo exes:
zig build -Ddemo
# Build the demo-c executable alongside the above:
zig build -Ddemo -Dcapi
```

Then run the first demo exe:
```sh
./zig-out/bin/demo delete # self-delete
./zig-out/bin/demo replace ?</path/to/new/exe> # self-replace; default path is ./zig-out/bin/demo2
```

Try out the `demo-c` exe which calls libreplace-exe from C:
```sh
./zig-out/bin/demo-c delete
# verify demo-c is deleted
```

---
### FFI via C ABI
If you're using it via FFI, the function signatures are defined in [replace_exe.h](include/replace_exe.h) and can be used in your code as the following:
- `selfReplace` becomes `self_replace(const char* path)`
- `selfDelete` becomes `self_delete()`
- `selfDeleteExcludingPath` becomes `self_delete_excluding_path(const char* path)`
- `init(?std.mem.Allocator)` becomes `init()`

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
