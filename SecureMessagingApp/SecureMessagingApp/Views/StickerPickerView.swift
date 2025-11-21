import SwiftUI

struct StickerPickerView: View {
    @Binding var isPresented: Bool
    var onStickerSelected: (String, String) -> Void  // (packId, stickerId)

    @State private var selectedPackId: String = "emotions"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sticker packs tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(BuiltInStickerPacks.allPacks) { pack in
                            Button(action: {
                                selectedPackId = pack.id
                            }) {
                                Text(pack.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedPackId == pack.id ? Color.indigo : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedPackId == pack.id ? .white : .primary)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)

                Divider()

                // Stickers grid for selected pack
                if let selectedPack = BuiltInStickerPacks.getPack(selectedPackId) {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                            ForEach(selectedPack.stickers) { sticker in
                                Button(action: {
                                    onStickerSelected(selectedPackId, sticker.id)
                                    isPresented = false
                                }) {
                                    Text(sticker.emoji)
                                        .font(.system(size: 44))
                                        .frame(height: 60)
                                        .frame(maxWidth: .infinity)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select a Sticker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.indigo)
                }
            }
            .background(Color(.systemBackground))
        }
    }
}

#Preview {
    @State var isPresented = true
    return StickerPickerView(isPresented: $isPresented, onStickerSelected: { _, _ in })
}
