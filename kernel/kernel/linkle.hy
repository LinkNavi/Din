project {
    name: "kernel",
    version: "0.1.0",
    author: "",
}

// Build target: "limine" compiles a Limine-bootable ELF64.
// Use "kernel" for a plain freestanding ELF (BIOS/Multiboot).
build {
    src: "src",
    main: "main",
    out: "build",
    bin: "kernel",
    target: "limine",
}

target clean() {
    exec("rm -rf build");
}
