import Quickshell.Io

// A command that runs alongside the shell, like a monitor waiting for its next event.
// The kernel ends it when the shell goes, even killed or crashed: left alone, it would
// keep waiting forever, one more after each restart.
Process {
    // What it runs, as a command would be given.
    required property var program

    command: ["setpriv", "--pdeathsig", "TERM", "--"].concat(program)
}
