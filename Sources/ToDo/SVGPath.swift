import SwiftUI

/// A small SVG path-data reader, so the six hand-drawn icons can be pasted in
/// verbatim from the design system instead of being redrawn straight.
/// Supports M m L l H h V v C c S s Q q T t Z z — the whole of this icon set.
enum SVGPath {

    static func path(_ d: String, in rect: CGRect, viewBox: CGFloat = 20) -> Path {
        var p = Path()
        let sx = rect.width / viewBox
        let sy = rect.height / viewBox

        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint?
        var lastCommand: Character = " "

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        for (command, nums) in tokenize(d) {
            let relative = command.isLowercase
            let upper = Character(command.uppercased())
            var i = 0

            func next() -> CGFloat { defer { i += 1 }; return i < nums.count ? nums[i] : 0 }
            func point() -> CGPoint {
                let x = next(), y = next()
                return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }

            repeat {
                switch upper {
                case "M":
                    current = point()
                    start = current
                    p.move(to: pt(current.x, current.y))
                    lastControl = nil
                case "L":
                    current = point()
                    p.addLine(to: pt(current.x, current.y))
                    lastControl = nil
                case "H":
                    let x = next()
                    current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                    p.addLine(to: pt(current.x, current.y))
                    lastControl = nil
                case "V":
                    let y = next()
                    current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                    p.addLine(to: pt(current.x, current.y))
                    lastControl = nil
                case "C":
                    let c1 = point(), c2 = point(), end = point()
                    p.addCurve(to: pt(end.x, end.y), control1: pt(c1.x, c1.y), control2: pt(c2.x, c2.y))
                    current = end
                    lastControl = c2
                case "S":
                    let reflected = "CS".contains(lastCommand.uppercased())
                        ? CGPoint(x: 2 * current.x - (lastControl?.x ?? current.x),
                                  y: 2 * current.y - (lastControl?.y ?? current.y))
                        : current
                    let c2 = point(), end = point()
                    p.addCurve(to: pt(end.x, end.y), control1: pt(reflected.x, reflected.y), control2: pt(c2.x, c2.y))
                    current = end
                    lastControl = c2
                case "Q":
                    let c = point(), end = point()
                    p.addQuadCurve(to: pt(end.x, end.y), control: pt(c.x, c.y))
                    current = end
                    lastControl = c
                case "T":
                    let c = "QT".contains(lastCommand.uppercased())
                        ? CGPoint(x: 2 * current.x - (lastControl?.x ?? current.x),
                                  y: 2 * current.y - (lastControl?.y ?? current.y))
                        : current
                    let end = point()
                    p.addQuadCurve(to: pt(end.x, end.y), control: pt(c.x, c.y))
                    current = end
                    lastControl = c
                case "Z":
                    p.closeSubpath()
                    current = start
                    lastControl = nil
                default:
                    break
                }
                lastCommand = command
                // A repeated coordinate set continues the same command; an implicit
                // M after the first pair is an L, per the SVG spec.
                if upper == "M" && i < nums.count { lastCommand = relative ? "l" : "L" }
            } while i < nums.count && upper != "Z"
        }
        return p
    }

    /// Splits "M3.4 3.8c4.2-.6 9.8-.4z" into [("M", [3.4, 3.8]), ("c", [...]), ("z", [])].
    private static func tokenize(_ d: String) -> [(Character, [CGFloat])] {
        var out: [(Character, [CGFloat])] = []
        var command: Character?
        var number = ""
        var numbers: [CGFloat] = []

        func flushNumber() {
            if !number.isEmpty, let v = Double(number) { numbers.append(CGFloat(v)) }
            number = ""
        }
        func flushCommand() {
            flushNumber()
            if let c = command { out.append((c, numbers)) }
            numbers = []
        }

        for ch in d {
            if ch.isLetter && ch != "e" && ch != "E" {
                flushCommand()
                command = ch
            } else if ch == "-" || ch == "+" {
                // A sign starts a new number unless it follows an exponent.
                if number.isEmpty || number.lowercased().hasSuffix("e") { number.append(ch) }
                else { flushNumber(); number.append(ch) }
            } else if ch == "." {
                // ".5.5" is two numbers.
                if number.contains(".") { flushNumber() }
                number.append(ch)
            } else if ch.isNumber || ch == "e" || ch == "E" {
                number.append(ch)
            } else {
                flushNumber()
            }
        }
        flushCommand()
        return out
    }
}

/// One hand-drawn stroke, tinted by the container. Stroke is 1.6 with round caps
/// and a deliberate wobble — never redraw one straight.
struct Icon: View {
    let paths: [String]
    /// They are single-ink: tint them in the container when you place one.
    var color: Color = Tk.ink
    var lineWidth: CGFloat = 1.6
    /// Icons are drawn on a 20x20 grid; some overshoot it on purpose.
    var side: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            for d in paths {
                context.stroke(
                    SVGPath.path(d, in: rect, viewBox: 20),
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth * (size.width / 20),
                                       lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(width: side, height: side)
    }
}

/// The six strokes that ship with the system. Nothing else is drawn as an icon —
/// if a concept needs more, it uses a word.
enum Glyph {
    static let note = [
        "M3.4 3.8c4.2-.6 9.8-.4 12.7-.3.3 4 .2 7 0 8.7l-4.4 4.4c-3.4.2-6.3 0-8.1-.2-.3-4.4-.3-8.9-.2-12.6z",
        "M16 12.2c-2.1-.1-3.9.1-4.2.4-.4.5-.3 2.3-.2 4.1"
    ]
    static let check = [
        "M3.2 10.4c2.4 2 3.6 3.8 5.1 6.2C11.1 11.4 14.8 6 19 2.1"
    ]
    static let plus = [
        "M10 3.1c.3 4.6.2 9.3.1 13.6M3.2 10.2c4.6-.3 9.3-.2 13.6-.1"
    ]
    static let cross = [
        "M4.4 4.1c3.7 3.9 7.5 7.6 11.4 11.6M15.7 4.3c-3.9 3.8-7.7 7.6-11.3 11.5"
    ]
    static let trash = [
        "M3.6 5.4c4.3-.5 8.6-.4 12.9-.2",
        "M6.4 5.3c.1-1 .3-1.9.6-2.1 1.7-.3 3.4-.3 5.1 0 .3.3.5 1.1.6 2.1",
        "M5.2 7.3c.2 3.6.5 6.9.9 9.1 2.6.3 5.2.3 7.8 0 .4-2.2.7-5.5.9-9.1"
    ]
    static let paper = [
        "M6.6 6.2c3.6-.5 7.4-.3 9.9-.2.2 3.4.1 6.8-.1 9.9-3.3.3-6.6.3-9.9.1-.2-3.2-.2-6.5.1-9.8z",
        "M13.3 3.6C10 3.2 6.6 3.3 3.3 3.8c-.3 3.1-.4 6.3-.2 9.4"
    ]
}
