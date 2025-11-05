package main

/*
#cgo CFLAGS: -I${SRCDIR}/../zig-out/include

// --- Shared (.so) build ---
// Build your Zig library with: zig build -Dcapi=true -Dshared=true
// Then Go will link dynamically against libreplace-exe.so
// #cgo LDFLAGS: -L${SRCDIR}/../zig-out/lib -lreplace-exe

// --- Static (.a) build ---
// Alternatively, build Zig with: zig build -Dcapi=true -Dshared=false
// and comment out the line above, then uncomment below to link statically
#cgo LDFLAGS: ${SRCDIR}/../zig-out/lib/libreplace-exe.a

#include <replace_exe.h>
#include <stdlib.h>
*/
import "C"

import (
	"fmt"
	"os"
	"unsafe"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage:")
		fmt.Println("  ./demo-go delete             # test self delete")
		fmt.Println("  ./demo-go replace <path>     # test self replace")
		return
	}

	cmd := os.Args[1]

	switch cmd {
	case "delete":
		fmt.Println("[Go] Calling re_self_delete() ...")
		res := C.re_self_delete()
		if res != 0 {
			fmt.Println("[Go] re_self_delete failed!")
		} else {
			fmt.Println("[Go] Success — process may delete itself 😅")
		}

	case "replace":
		if len(os.Args) < 3 {
			fmt.Println("Usage: ./demo-go replace <path>")
			os.Exit(1)
		}
		path := C.CString(os.Args[2])
		defer C.free(unsafe.Pointer(path))

		fmt.Printf("[Go] Calling re_self_replace(%q) ...\n", os.Args[2])
		res := C.re_self_replace(path)
		if res != 0 {
			fmt.Println("[Go] re_self_replace failed!")
		} else {
			fmt.Println("[Go] Replacement succeeded!")
		}

	default:
		fmt.Println("Unknown command:", cmd)
	}
}
