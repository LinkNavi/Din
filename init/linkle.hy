project {
    name: "init",
    version: "0.1.0",
    author: "",
}

build {
    src: "src",
    main: "main",
    out: "build",
    bin: "init",
}

target clean() {
    exec("rm -rf build");
}
