// Workspace root — lists all packages in this project.
// Each entry is a directory containing its own linkle.hy.
//
// Build all:    linkle build
// Clean all:    linkle clean
// Build one:    cd <member> && linkle build
workspace {
    members: ["kernel", "init"],
}
