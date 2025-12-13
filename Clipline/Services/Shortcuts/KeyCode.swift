//
//  KeyCode.swift
//  Clipline
//
//  Created by mazhj on 2025/12/1.
//

import AppKit
import Carbon
import Foundation

public struct Key: Hashable, RawRepresentable, Sendable {
    // MARK: Letters

    public static let a = Self(kVK_ANSI_A)
    public static let b = Self(kVK_ANSI_B)
    public static let c = Self(kVK_ANSI_C)
    public static let d = Self(kVK_ANSI_D)
    public static let e = Self(kVK_ANSI_E)
    public static let f = Self(kVK_ANSI_F)
    public static let g = Self(kVK_ANSI_G)
    public static let h = Self(kVK_ANSI_H)
    public static let i = Self(kVK_ANSI_I)
    public static let j = Self(kVK_ANSI_J)
    public static let k = Self(kVK_ANSI_K)
    public static let l = Self(kVK_ANSI_L)
    public static let m = Self(kVK_ANSI_M)
    public static let n = Self(kVK_ANSI_N)
    public static let o = Self(kVK_ANSI_O)
    public static let p = Self(kVK_ANSI_P)
    public static let q = Self(kVK_ANSI_Q)
    public static let r = Self(kVK_ANSI_R)
    public static let s = Self(kVK_ANSI_S)
    public static let t = Self(kVK_ANSI_T)
    public static let u = Self(kVK_ANSI_U)
    public static let v = Self(kVK_ANSI_V)
    public static let w = Self(kVK_ANSI_W)
    public static let x = Self(kVK_ANSI_X)
    public static let y = Self(kVK_ANSI_Y)
    public static let z = Self(kVK_ANSI_Z)
    // swiftlint:enable identifier_name

    // MARK: Numbers

    public static let zero = Self(kVK_ANSI_0)
    public static let one = Self(kVK_ANSI_1)
    public static let two = Self(kVK_ANSI_2)
    public static let three = Self(kVK_ANSI_3)
    public static let four = Self(kVK_ANSI_4)
    public static let five = Self(kVK_ANSI_5)
    public static let six = Self(kVK_ANSI_6)
    public static let seven = Self(kVK_ANSI_7)
    public static let eight = Self(kVK_ANSI_8)
    public static let nine = Self(kVK_ANSI_9)

    // MARK: Modifiers

    public static let capsLock = Self(kVK_CapsLock)
    public static let shift = Self(kVK_Shift)
    public static let function = Self(kVK_Function)
    public static let control = Self(kVK_Control)
    public static let option = Self(kVK_Option)
    public static let command = Self(kVK_Command)
    public static let rightCommand = Self(kVK_RightCommand)
    public static let rightOption = Self(kVK_RightOption)
    public static let rightControl = Self(kVK_RightControl)
    public static let rightShift = Self(kVK_RightShift)

    // MARK: Miscellaneous

    public static let `return` = Self(kVK_Return)
    public static let backslash = Self(kVK_ANSI_Backslash)
    public static let backtick = Self(kVK_ANSI_Grave)
    public static let comma = Self(kVK_ANSI_Comma)
    public static let equal = Self(kVK_ANSI_Equal)
    public static let minus = Self(kVK_ANSI_Minus)
    public static let period = Self(kVK_ANSI_Period)
    public static let quote = Self(kVK_ANSI_Quote)
    public static let semicolon = Self(kVK_ANSI_Semicolon)
    public static let slash = Self(kVK_ANSI_Slash)
    public static let space = Self(kVK_Space)
    public static let tab = Self(kVK_Tab)
    public static let leftBracket = Self(kVK_ANSI_LeftBracket)
    public static let rightBracket = Self(kVK_ANSI_RightBracket)
    public static let pageUp = Self(kVK_PageUp)
    public static let pageDown = Self(kVK_PageDown)
    public static let home = Self(kVK_Home)
    public static let end = Self(kVK_End)
    public static let upArrow = Self(kVK_UpArrow)
    public static let rightArrow = Self(kVK_RightArrow)
    public static let downArrow = Self(kVK_DownArrow)
    public static let leftArrow = Self(kVK_LeftArrow)
    public static let escape = Self(kVK_Escape)
    public static let delete = Self(kVK_Delete)
    public static let deleteForward = Self(kVK_ForwardDelete)
    public static let help = Self(kVK_Help)
    public static let mute = Self(kVK_Mute)
    public static let volumeUp = Self(kVK_VolumeUp)
    public static let volumeDown = Self(kVK_VolumeDown)

    // MARK: Function

    public static let f1 = Self(kVK_F1)
    public static let f2 = Self(kVK_F2)
    public static let f3 = Self(kVK_F3)
    public static let f4 = Self(kVK_F4)
    public static let f5 = Self(kVK_F5)
    public static let f6 = Self(kVK_F6)
    public static let f7 = Self(kVK_F7)
    public static let f8 = Self(kVK_F8)
    public static let f9 = Self(kVK_F9)
    public static let f10 = Self(kVK_F10)
    public static let f11 = Self(kVK_F11)
    public static let f12 = Self(kVK_F12)
    public static let f13 = Self(kVK_F13)
    public static let f14 = Self(kVK_F14)
    public static let f15 = Self(kVK_F15)
    public static let f16 = Self(kVK_F16)
    public static let f17 = Self(kVK_F17)
    public static let f18 = Self(kVK_F18)
    public static let f19 = Self(kVK_F19)
    public static let f20 = Self(kVK_F20)

    // MARK: Keypad

    public static let keypad0 = Self(kVK_ANSI_Keypad0)
    public static let keypad1 = Self(kVK_ANSI_Keypad1)
    public static let keypad2 = Self(kVK_ANSI_Keypad2)
    public static let keypad3 = Self(kVK_ANSI_Keypad3)
    public static let keypad4 = Self(kVK_ANSI_Keypad4)
    public static let keypad5 = Self(kVK_ANSI_Keypad5)
    public static let keypad6 = Self(kVK_ANSI_Keypad6)
    public static let keypad7 = Self(kVK_ANSI_Keypad7)
    public static let keypad8 = Self(kVK_ANSI_Keypad8)
    public static let keypad9 = Self(kVK_ANSI_Keypad9)
    public static let keypadClear = Self(kVK_ANSI_KeypadClear)
    public static let keypadDecimal = Self(kVK_ANSI_KeypadDecimal)
    public static let keypadDivide = Self(kVK_ANSI_KeypadDivide)
    public static let keypadEnter = Self(kVK_ANSI_KeypadEnter)
    public static let keypadEquals = Self(kVK_ANSI_KeypadEquals)
    public static let keypadMinus = Self(kVK_ANSI_KeypadMinus)
    public static let keypadMultiply = Self(kVK_ANSI_KeypadMultiply)
    public static let keypadPlus = Self(kVK_ANSI_KeypadPlus)

    // MARK: Properties

    /**
    The raw key code.
    */
    public let rawValue: Int

    // MARK: Initializers

    /**
    Create a `Key` from a key code.
    */
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    private init(_ value: Int) {
        self.init(rawValue: value)
    }

    var symbol: String {
        switch self {
        case .return: return "⏎"
        case .tab: return "⇥"
        case .space: return "Space"
        case .delete: return "⌫"
        case .escape: return "⎋"
        case .command: return "⌘"
        case .shift: return "⇧"
        case .capsLock: return "⇪"
        case .option: return "⌥"
        case .control: return "⌃"
        case .rightShift: return "⇧"
        case .rightOption: return "⌥"
        case .rightControl: return "⌃"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .downArrow: return "↓"
        case .upArrow: return "↑"
        case .function: return "fn"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .zero: return "0"
        case .minus: return "-"
        case .equal: return "="
        case .leftBracket: return "["
        case .rightBracket: return "]"
        case .backslash: return "\\"
        case .semicolon: return ";"
        case .quote: return "'"
        case .comma: return ","
        case .period: return "."
        case .slash: return "/"
        // 功能键
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        // 字母键简单处理
        default:
            // 这里可以通过 Carbon API 获取更准确的本地化字符，但为简化，我们假设 KeyCode 命名即字符
            return String(describing: self).uppercased()
        }
    }
}

extension NSEvent.ModifierFlags {
    /// Follow Apple HIG: Control (⌃) -> Option (⌥) -> Shift (⇧) -> Command (⌘)
    var symbol: String {
        var str = ""
        // 1. Control
        if contains(.control) { str += "⌃" }
        // 2. Option (Alt)
        if contains(.option) { str += "⌥" }
        // 3. Shift
        if contains(.shift) { str += "⇧" }
        // 4. Command
        if contains(.command) { str += "⌘" }
        return str
    }
}

//struct Modifier {
//    let keycode: KeyCode
//    // MARK: - Modifier Keys (As physical keys)
//    static let command: Modifier = .init(keycode: .command)
//    static let shift: Modifier = .init(keycode: .shift)
//    static let option: Modifier = .init(keycode: .option)
//    static let control: Modifier = .init(keycode: .control)
//    static let capsLock: Modifier = .init(keycode: .capsLock)
//    static let function: Modifier = .init(keycode: .function)
//
//}
