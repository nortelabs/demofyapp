import SwiftUI

struct DropZone: View {
    let title: String
    @Binding var url: URL?
    @State private var isTargeted = false

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding(.top)

            if let url = url {
                Text(url.lastPathComponent)
                    .padding()
            } else {
                Image(systemName: "square.and.arrow.down")
                    .font(.largeTitle)
                    .padding()
            }

            Spacer()
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(isTargeted ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isTargeted ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else {
                return false
            }

            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                guard let data = item as? Data, let fileURL = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    self.url = fileURL
                }
            }
            return true
        }
    }
}
