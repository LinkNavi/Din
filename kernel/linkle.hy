project {
    name: "kernel",
    version: "0.1.0",
    author: "",
}

build {
    src: "src",
    main: "main",
    out: "build",
    bin: "Din",
    target: "limine",
}

target clean() {
    exec("rm -rf build");
}
