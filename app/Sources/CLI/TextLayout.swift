import Foundation

private enum EscapeState {
    case text
    case afterEscape
    case insideCSI
}

private func scan(_ text: String, keeping keep: ((Character) -> Void)? = nil) -> Int {
    var state = EscapeState.text
    var visible = 0
    for character in text {
        switch state {
        case .text:
            if character == "\u{1B}" {
                state = .afterEscape
            } else {
                visible += 1
                keep?(character)
            }
        case .afterEscape:
            state = (character == "[") ? .insideCSI : .text
        case .insideCSI:
            if let ascii = character.asciiValue, ascii >= 0x40, ascii <= 0x7E {
                state = .text
            }
        }
    }
    return visible
}

package func visibleLength(_ text: String) -> Int {
    scan(text)
}

package func stripANSI(_ text: String) -> String {
    var result = ""
    result.reserveCapacity(text.count)
    _ = scan(text) { result.append($0) }
    return result
}

package func pad(_ text: String, _ width: Int) -> String {
    let length = visibleLength(text)
    return length >= width ? text : text + String(repeating: " ", count: width - length)
}

package func trimTrailing(_ text: String) -> String {
    var result = text
    while result.hasSuffix(" ") { result.removeLast() }
    return result
}
