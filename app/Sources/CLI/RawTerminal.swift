import Foundation

nonisolated(unsafe) private var savedTermios = termios()
nonisolated(unsafe) private var termiosSaved = false

enum Key {
    case up, down, enter, back, quit
    case search
    case character(Character)
    case backspace
    case other
}

enum RawTerminal {
    static var isInteractive: Bool {
        isatty(STDIN_FILENO) == 1
            && isatty(STDOUT_FILENO) == 1
            && ProcessInfo.processInfo.environment["TERM"] != "dumb"
    }

    static func enterRawMode() {
        guard tcgetattr(STDIN_FILENO, &savedTermios) == 0 else { return }
        termiosSaved = true
        var inputSettings = savedTermios
        inputSettings.c_lflag &= ~UInt(ECHO | ICANON)
        withUnsafeMutableBytes(of: &inputSettings.c_cc) { controls in
            controls[Int(VMIN)] = 1
            controls[Int(VTIME)] = 0
        }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &inputSettings)
        for interruption in [SIGINT, SIGTERM] {
            signal(interruption) { received in
                RawTerminal.restore()
                exit(128 + received)
            }
        }
        atexit { RawTerminal.restore() }
        emit("\u{1B}[?1049h\u{1B}[?25l")
    }

    static func restore() {
        guard termiosSaved else { return }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &savedTermios)
        termiosSaved = false
        emit("\u{1B}[?25h\u{1B}[?1049l")
    }

    static func emit(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    static var size: (rows: Int, columns: Int) {
        var window = winsize()
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &window) == 0, window.ws_row > 0 {
            return (Int(window.ws_row), Int(window.ws_col))
        }
        return (24, 80)
    }

    static func readKey(searching: Bool) -> Key {
        guard let byte = readByte() else { return .quit }

        switch byte {
        case 0x0D, 0x0A: return .enter
        case 0x03, 0x04: return .quit
        case 0x7F, 0x08: return .backspace
        case 0x1B: return readEscapeSequence()
        default: break
        }

        if searching {
            let scalar = UnicodeScalar(byte)
            return scalar.isASCII && scalar.value >= 0x20 ? .character(Character(scalar)) : .other
        }

        switch byte {
        case 0x20: return .enter
        case 0x6B, 0x4B: return .up
        case 0x6A, 0x4A: return .down
        case 0x68: return .back
        case 0x71, 0x51: return .quit
        case 0x2F: return .search
        default: return .other
        }
    }

    private static func readEscapeSequence() -> Key {
        guard byteReady(within: 50), let next = readByte() else { return .back }
        guard next == 0x5B, let final = readByte() else { return .other }
        switch final {
        case 0x41: return .up
        case 0x42: return .down
        case 0x44: return .back
        default: return .other
        }
    }

    private static func readByte() -> UInt8? {
        var byte: UInt8 = 0
        return read(STDIN_FILENO, &byte, 1) == 1 ? byte : nil
    }

    private static func byteReady(within milliseconds: Int32) -> Bool {
        var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        return poll(&descriptor, 1, milliseconds) > 0
    }
}
