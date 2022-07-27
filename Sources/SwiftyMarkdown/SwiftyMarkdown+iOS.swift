//
//  SwiftyMarkdown+macOS.swift
//  SwiftyMarkdown
//
//  Created by Simon Fairbairn on 17/12/2019.
//  Copyright © 2019 Voyage Travel Apps. All rights reserved.
//

import Foundation

#if !os(macOS)
import UIKit

extension SwiftyMarkdown {
    
    func font( for line : SwiftyLine, characterOverride : CharacterStyle? = nil ) -> UIFont {
        let textStyle : UIFont.TextStyle
        var fontName : String?
        var fontSize : CGFloat?
        
        var globalBold = false
        var globalItalic = false
        
        let style : FontProperties
        // What type are we and is there a font name set?
        switch line.lineStyle as! MarkdownLineStyle {
        case .h1:
            style = self.h1
            if #available(iOS 9, *) {
                textStyle = UIFont.TextStyle.title1
            } else {
                textStyle = UIFont.TextStyle.headline
            }
        case .h2:
            style = self.h2
            if #available(iOS 9, *) {
                textStyle = UIFont.TextStyle.title2
            } else {
                textStyle = UIFont.TextStyle.headline
            }
        case .h3:
            style = self.h3
            if #available(iOS 9, *) {
                textStyle = UIFont.TextStyle.title2
            } else {
                textStyle = UIFont.TextStyle.subheadline
            }
        case .h4:
            style = self.h4
            textStyle = UIFont.TextStyle.headline
        case .h5:
            style = self.h5
            textStyle = UIFont.TextStyle.subheadline
        case .h6:
            style = self.h6
            textStyle = UIFont.TextStyle.footnote
        case .codeblock:
            style = self.code
            textStyle = UIFont.TextStyle.body
        case .blockquote:
            style = self.blockquotes
            textStyle = UIFont.TextStyle.body
        case .breakParagraph:
            style = self.breakParagraph
            textStyle = UIFont.TextStyle.body
        default:
            style = self.body
            textStyle = UIFont.TextStyle.body
        }
        
        fontName = style.fontName
        fontSize = style.fontSize
        switch style.fontStyle {
        case .bold:
            globalBold = true
        case .italic:
            globalItalic = true
        case .boldItalic:
            globalItalic = true
            globalBold = true
        case .normal:
            break
        }

        if fontName == nil {
            fontName = body.fontName
        }
        
        if let characterOverride = characterOverride {
            switch characterOverride {
            case .code:
                fontName = code.fontName ?? fontName
                fontSize = code.fontSize
            case .link:
                fontName = link.fontName ?? fontName
                fontSize = link.fontSize
            case .bold:
                fontName = fontName ?? bold.fontName
                fontSize = fontSize ?? bold.fontSize
                globalBold = true
            case .italic:
                fontName = fontName ?? italic.fontName
                fontSize = fontSize ?? italic.fontSize
                globalItalic = true
            case .boldItalic:
                fontName = fontName ?? bold.fontName
                fontSize = fontSize ?? bold.fontSize
                globalBold = true
                globalItalic = true
            case .strikethrough:
                fontName = fontName ?? strikethrough.fontName
                fontSize = fontSize ?? strikethrough.fontSize
            default:
                break
            }
        }
        
        fontSize = fontSize == 0.0 ? nil : fontSize
        var font : UIFont
        if var existentFontName = fontName {
            if usingReplaceFontRule {
                existentFontName = applyReplaceFontRule(fontName: existentFontName, globalBold: globalBold,
                                                        globalItalic: globalItalic)
            }
            font = UIFont.preferredFont(forTextStyle: textStyle)
            let finalSize : CGFloat
            if let existentFontSize = fontSize {
                finalSize = existentFontSize
            } else {
                let styleDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle)
                finalSize = styleDescriptor.fontAttributes[.size] as? CGFloat ?? CGFloat(14)
            }
            
            if let customFont = UIFont(name: existentFontName, size: finalSize)  {
                if #available(iOS 11.0, *) {
                    let fontMetrics = UIFontMetrics(forTextStyle: textStyle)
                    font = fontMetrics.scaledFont(for: customFont)
                }
                else {
                    font = customFont
                }
            } else {
                font = UIFont.preferredFont(forTextStyle: textStyle)
            }
        } else {
            font = UIFont.preferredFont(forTextStyle: textStyle)
        }
        
        if !usingReplaceFontRule,
           let symtraiFont = applySymTrails(font: font, globalBold: globalBold, globalItalic: globalItalic) {
            font = symtraiFont
        }
        
        return font
        
    }
    
    func color( for line : SwiftyLine ) -> UIColor {
        // What type are we and is there a font name set?
        switch line.lineStyle as! MarkdownLineStyle {
        case .yaml:
            return body.color
        case .h1, .previousH1:
            return h1.color
        case .h2, .previousH2:
            return h2.color
        case .h3:
            return h3.color
        case .h4:
            return h4.color
        case .h5:
            return h5.color
        case .h6:
            return h6.color
        case .body:
            return body.color
        case .codeblock:
            return code.color
        case .blockquote:
            return blockquotes.color
        case .unorderedList, .unorderedListIndentFirstOrder, .unorderedListIndentSecondOrder, .orderedList, .orderedListIndentFirstOrder, .orderedListIndentSecondOrder:
            return body.color
        case .referencedLink:
            return link.color
        case .breakParagraph:
            return breakParagraph.color
        }
    }
    
    private func applyReplaceFontRule(fontName: String, globalBold: Bool, globalItalic: Bool) -> String {
        var result: String = fontName
        if globalBold {
            var components: [String] = result.components(separatedBy: "-")
            let lastIndex: Int = components.count - 1
            if lastIndex > 0 {
                // example replace SFProText-Regular -> SFProText-Bold
                components[lastIndex] = "Bold"
            }
            result = components.joined(separator: "-")
        }
        if globalItalic {
            result.append(contentsOf: "Italic")
        }
        return result
    }
    
    private func applySymTrails(font: UIFont, globalBold: Bool, globalItalic: Bool) -> UIFont? {
        var symTrails: UIFontDescriptor.SymbolicTraits = []
        if globalItalic {
            symTrails.insert(.traitItalic)
        }
        if globalBold {
            symTrails.insert(.traitBold)
        }
        if !symTrails.isEmpty, let descriptor = font.fontDescriptor.withSymbolicTraits(symTrails) {
            return UIFont(descriptor: descriptor, size: 0)
        }
        return nil
    }
}
#endif
