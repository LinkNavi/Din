project {
    name: "Din",
    version: "0.1.0",
    author: "",
}

build {
    src: "src",
    main: "main",
    out: "build",
    bin: "Din",
}

// Declare native or Hylian vendor packages here.
// Each entry maps an include alias to a folder inside vendors/.
//
// vendors {
//     sdl2: "vendors/sdl2",
// }

target run() {
    exec("./build/bin/Din");
}

target clean() {
    exec("rm -rf build");
}
