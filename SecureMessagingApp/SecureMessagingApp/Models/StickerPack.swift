import SwiftUI

// Represents a single sticker in a pack
struct Sticker: Identifiable, Codable {
    let id: String
    let emoji: String
    let name: String
}

// Represents a collection of stickers
struct StickerPack: Identifiable {
    let id: String
    let name: String
    let stickers: [Sticker]
}

// Built-in sticker packs
enum BuiltInStickerPacks {
    static let allPacks: [StickerPack] = [
        StickerPack(
            id: "emotions",
            name: "Emotions",
            stickers: [
                Sticker(id: "happy", emoji: "😊", name: "Happy"),
                Sticker(id: "sad", emoji: "😢", name: "Sad"),
                Sticker(id: "laugh", emoji: "😂", name: "Laughing"),
                Sticker(id: "love", emoji: "😍", name: "Love"),
                Sticker(id: "cool", emoji: "😎", name: "Cool")
            ]
        ),
        StickerPack(
            id: "celebrations",
            name: "Celebrations",
            stickers: [
                Sticker(id: "party", emoji: "🎉", name: "Party"),
                Sticker(id: "birthday", emoji: "🎂", name: "Birthday"),
                Sticker(id: "fireworks", emoji: "🎆", name: "Fireworks"),
                Sticker(id: "balloons", emoji: "🎈", name: "Balloons"),
                Sticker(id: "champagne", emoji: "🥂", name: "Cheers")
            ]
        ),
        StickerPack(
            id: "hand-gestures",
            name: "Hand Gestures",
            stickers: [
                Sticker(id: "thumbsup", emoji: "👍", name: "Thumbs Up"),
                Sticker(id: "thumbsdown", emoji: "👎", name: "Thumbs Down"),
                Sticker(id: "wave", emoji: "👋", name: "Wave"),
                Sticker(id: "ok", emoji: "👌", name: "OK"),
                Sticker(id: "fist", emoji: "✊", name: "Fist")
            ]
        ),
        StickerPack(
            id: "animals",
            name: "Animals",
            stickers: [
                Sticker(id: "cat", emoji: "😸", name: "Cat Face"),
                Sticker(id: "dog", emoji: "😺", name: "Dog Face"),
                Sticker(id: "monkey", emoji: "🐵", name: "Monkey"),
                Sticker(id: "pig", emoji: "🐷", name: "Pig"),
                Sticker(id: "bear", emoji: "🐻", name: "Bear")
            ]
        ),
        StickerPack(
            id: "love-romance",
            name: "Love & Romance",
            stickers: [
                Sticker(id: "heart", emoji: "❤️", name: "Heart"),
                Sticker(id: "broken-heart", emoji: "💔", name: "Broken Heart"),
                Sticker(id: "kiss", emoji: "💋", name: "Kiss"),
                Sticker(id: "couple", emoji: "💑", name: "Couple"),
                Sticker(id: "rose", emoji: "🌹", name: "Rose")
            ]
        ),
        StickerPack(
            id: "objects",
            name: "Objects",
            stickers: [
                Sticker(id: "star", emoji: "⭐", name: "Star"),
                Sticker(id: "fire", emoji: "🔥", name: "Fire"),
                Sticker(id: "rocket", emoji: "🚀", name: "Rocket"),
                Sticker(id: "bomb", emoji: "💣", name: "Bomb"),
                Sticker(id: "gift", emoji: "🎁", name: "Gift")
            ]
        )
    ]

    // Get a specific sticker pack by ID
    static func getPack(_ id: String) -> StickerPack? {
        return allPacks.first { $0.id == id }
    }

    // Get a specific sticker by pack ID and sticker ID
    static func getSticker(packId: String, stickerId: String) -> Sticker? {
        guard let pack = getPack(packId) else { return nil }
        return pack.stickers.first { $0.id == stickerId }
    }
}
