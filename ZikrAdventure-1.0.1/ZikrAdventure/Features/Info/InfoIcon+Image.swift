// InfoIcon+Image.swift
// ZKR-48: иконки экрана «Инфо» — vector-ассеты из набора P в index.html.

import SwiftUI
import ZikrContent

extension InfoIcon {
    var assetName: String {
        switch self {
        case .info: return "TabInfo"
        case .path: return "TabPath"
        case .map: return "TabMap"
        case .book: return "InfoBook"
        case .lock: return "InfoLock"
        case .star: return "InfoStar"
        case .urban: return "InfoUrban"
        case .hand: return "InfoHand"
        case .list: return "InfoList"
        }
    }

    var image: Image { Image(assetName) }
}
