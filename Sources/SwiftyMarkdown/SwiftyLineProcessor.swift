//
//  SwiftyLineProcessor.swift
//  SwiftyMarkdown
//
//  Created by Simon Fairbairn on 16/12/2019.
//  Copyright © 2019 Voyage Travel Apps. All rights reserved.
//

import Foundation
import os.log

extension OSLog {
    private static var subsystem = "SwiftyLineProcessor"
    static let swiftyLineProcessorPerformance = OSLog(subsystem: subsystem, category: "Swifty Line Processor Performance")
}

public protocol LineStyling {
    var shouldTokeniseLine : Bool { get }
    func styleIfFoundStyleAffectsPreviousLine() -> LineStyling?
}

public struct SwiftyLine : CustomStringConvertible {
    public let line : String
    public let lineStyle : LineStyling
    public var description: String {
        return self.line
    }
}

extension SwiftyLine : Equatable {
    public static func == ( _ lhs : SwiftyLine, _ rhs : SwiftyLine ) -> Bool {
        return lhs.line == rhs.line
    }
}

public enum Remove {
    case leading
    case trailing
    case both
    case entireLine
    case none
}

public enum ChangeApplication {
    case current
    case previous
    case untilClose
}

public struct FrontMatterRule {
    let openTag : String
    let closeTag : String
    let keyValueSeparator : Character
}

public struct LineRule {
    let token : String
    let removeFrom : Remove
    let type : LineStyling
    let shouldTrim : Bool
    let changeAppliesTo : ChangeApplication
    
    public init(token : String, type : LineStyling, removeFrom : Remove = .leading, shouldTrim : Bool = true, changeAppliesTo : ChangeApplication = .current ) {
        self.token = token
        self.type = type
        self.removeFrom = removeFrom
        self.shouldTrim = shouldTrim
        self.changeAppliesTo = changeAppliesTo
    }
}

public class SwiftyLineProcessor {
    
    public var processEmptyStrings : LineStyling?
    public internal(set) var frontMatterAttributes : [String : String] = [:]
    
    var processingMultilineRule: LineRule? = nil
    let defaultType : LineStyling
    
    let lineRules : [LineRule]
    let frontMatterRules : [FrontMatterRule]
    
    let perfomanceLog = PerformanceLog(with: "SwiftyLineProcessorPerformanceLogging", identifier: "Line Processor", log: OSLog.swiftyLineProcessorPerformance)
    
    public init( rules : [LineRule], defaultRule: LineStyling, frontMatterRules : [FrontMatterRule] = []) {
        self.lineRules = rules
        self.defaultType = defaultRule
        self.frontMatterRules = frontMatterRules
    }
    
    func findLeadingLineElement( _ element : LineRule, in string : String ) -> String {
        var output = string
        if let range = output.index(output.startIndex, offsetBy: element.token.count, limitedBy: output.endIndex), output[output.startIndex..<range] == element.token {
            output.removeSubrange(output.startIndex..<range)
            return output
        }
        return output
    }
    
    func findTrailingLineElement( _ element : LineRule, in string : String ) -> String {
        var output = string
        let token = element.token.trimmingCharacters(in: .whitespaces)
        if let range = output.index(output.endIndex, offsetBy: -(token.count), limitedBy: output.startIndex), output[range..<output.endIndex] == token {
            output.removeSubrange(range..<output.endIndex)
            return output
            
        }
        return output
    }
    
    private func hasEndingLineElement(_ element: LineRule, _ entireLines: [String]) -> Bool {
        return entireLines.filter { $0 == element.token }.count > 0
    }
    
    func processLineLevelAttributes(_ text : String, _ entireLines: [String], _ textBefore: String) -> SwiftyLine? {
        if text.isEmpty, let style = processEmptyStrings {
            return SwiftyLine(line: "", lineStyle: style)
        }
        let previousLines = lineRules.filter({ $0.changeAppliesTo == .previous })
        
        for element in lineRules {
            guard element.token.count > 0 else {
                continue
            }
            
            var output : String = (element.shouldTrim) ? text.trimmingCharacters(in: .whitespaces) : text
            let unprocessed = output
            
            if let hasRule = processingMultilineRule, unprocessed != hasRule.token {
                return SwiftyLine(line: unprocessed, lineStyle: hasRule.type)
            }
            
            if element.token == NumberingList.level1.rawValue || element.token == NumberingList.level2.rawValue || element.token == NumberingList.level3.rawValue {
                output = processOrderListRegex(output)
                let lineBefore = processOrderListRegex(textBefore)
                if output.starts(with: NumberingList.level2.rawValue) {
                    if !lineBefore.trimmingCharacters(in: .whitespaces).starts(with: NumberingList.level1.rawValue) {
                        output = output.trimmingCharacters(in: .whitespaces)
                    }
                } else if output.starts(with: NumberingList.level3.rawValue) {
                    if !lineBefore.trimmingCharacters(in: .whitespaces).starts(with: NumberingList.level1.rawValue) {
                        output = output.trimmingCharacters(in: .whitespaces)
                    }
                }
            }
            
            if !output.contains(element.token) {
                continue
            }
            
            switch element.removeFrom {
            case .leading:
                output = findLeadingLineElement(element, in: output)
            case .trailing:
                output = findTrailingLineElement(element, in: output)
            case .both:
                output = findLeadingLineElement(element, in: output)
                output = findTrailingLineElement(element, in: output)
            case .entireLine:
                let maybeOutput = output.replacingOccurrences(of: element.token, with: "")
                output = ( maybeOutput.isEmpty ) ? maybeOutput : output
            default:
                break
            }
            // Only if the output has changed in some way
            guard unprocessed != output else {
                continue
            }
            if element.changeAppliesTo == .untilClose {
                if processingMultilineRule == nil && !hasEndingLineElement(element, entireLines) {
                    // if dont has ending close, should not apply this rule
                    continue
                } else {
                    processingMultilineRule = (processingMultilineRule == nil) ? element : nil
                }
            }
            
            output = (element.shouldTrim) ? output.trimmingCharacters(in: .whitespaces) : output
            return SwiftyLine(line: output, lineStyle: element.type)
        }
        
        for element in previousLines {
            let output = (element.shouldTrim) ? text.trimmingCharacters(in: .whitespaces) : text
            let charSet = CharacterSet(charactersIn: element.token )
            if output.unicodeScalars.allSatisfy({ charSet.contains($0) }) {
                return SwiftyLine(line: "", lineStyle: element.type)
            }
        }
        
        return SwiftyLine(line: text.trimmingCharacters(in: .whitespaces), lineStyle: defaultType)
    }
    
    func processFrontMatter( _ strings : [String] ) -> [String] {
        guard let firstString = strings.first?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return strings
        }
        var rulesToApply : FrontMatterRule? = nil
        for matter in self.frontMatterRules {
            if firstString == matter.openTag {
                rulesToApply = matter
                break
            }
        }
        
        guard let existentRules = rulesToApply else {
            return strings
        }
        var outputString = strings
        // Remove the first line, which is the front matter opening tag
        let _ = outputString.removeFirst()
        var closeFound = false
        while !closeFound {
            let nextString = outputString.removeFirst()
            if nextString == existentRules.closeTag {
                closeFound = true
                continue
            }
            var keyValue = nextString.components(separatedBy: "\(existentRules.keyValueSeparator)")
            if keyValue.count < 2 {
                continue
            }
            let key = keyValue.removeFirst()
            let value = keyValue.joined()
            self.frontMatterAttributes[key] = value
        }
        while outputString.first?.isEmpty ?? false {
            outputString.removeFirst()
        }
        
        return outputString
    }
    
    public func process( _ string : String ) -> [SwiftyLine] {
        var foundAttributes : [SwiftyLine] = []
        
        self.perfomanceLog.start()
        
        // when input rtf in macos web, this will use `\r\n` for new line
        var lines = string.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: CharacterSet.newlines)
        lines = self.processFrontMatter(lines)
        
        self.perfomanceLog.tag(with: "(Front matter completed)")
        
        for (index, heading) in lines.enumerated() {
            
            if processEmptyStrings == nil && heading.isEmpty {
                continue
            }
            
            let entireLines: [String] = lines.enumerated().filter { $0.offset > index }.map { $0.element }
            
            var tempHeading = heading
            if index == lines.count - 1, tempHeading.last == "-" {
                let indexLineBefore = index - 1
                if indexLineBefore >= 0 {
                    let lineBefore = lines[indexLineBefore]
                    if lineBefore.starts(with: BulletList.level1.rawValue) || lineBefore.starts(with: BulletList.level2.rawValue) || lineBefore.starts(with: BulletList.level3.rawValue) {
                        tempHeading = tempHeading + " "
                    }
                }
            }
            
            var lineTextBefore = ""
            let indexLineBefore = index - 1
            if indexLineBefore >= 0 {
                lineTextBefore = lines[indexLineBefore]
            }
            
            guard let input = processLineLevelAttributes(String(tempHeading), entireLines, lineTextBefore) else {
                continue
            }
            
            if let existentPrevious = input.lineStyle.styleIfFoundStyleAffectsPreviousLine(), foundAttributes.count > 0 {
                if let idx = foundAttributes.firstIndex(of: foundAttributes.last!) {
                    let updatedPrevious = foundAttributes.last!
                    foundAttributes[idx] = SwiftyLine(line: updatedPrevious.line, lineStyle: existentPrevious)
                }
                continue
            }
            foundAttributes.append(input)
            
            self.perfomanceLog.tag(with: "(line completed: \(heading)")
        }
        return foundAttributes
    }
    
    func processOrderListRegex(_ text: String) -> String {
        var result: String = text.trimmingCharacters(in: .whitespaces) + " " // to support `7. ` be replaced to `7.`
        
        let pattern = "^[0-9]+\\. "
        
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSMakeRange(0, result.count)
        
        result = regex?.stringByReplacingMatches(in: result, options: [], range: range,
                                                 withTemplate: "1. ") ?? result
        
        if text.contains(SwiftyMarkdown.eightSpace) {
            result = SwiftyMarkdown.eightSpace + result
        } else if text.contains(SwiftyMarkdown.fourSpace) {
            result = SwiftyMarkdown.fourSpace + result
        }
        
        if result != "1. " {
            result = String(result.dropLast())
        }
        return result
    }
    
}
