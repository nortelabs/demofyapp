import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var viewModel = ViewModel()

    var body: some View {
        VStack(spacing: 32) {
            // Header
            Text("Demofy")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)
                .padding(.top, 16)

            // Action Buttons
            HStack(spacing: 24) {
                Button(action: {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.showSavePanelAndStartRecording()
                    }
                }) {
                    HStack {
                        Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                            .foregroundColor(viewModel.isRecording ? .red : .accentColor)
                        Text(viewModel.isRecording ? "Stop Recording" : "Record Simulator")
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(viewModel.isRecording ? Color.red.opacity(0.1) : Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }

                Button(action: {
                    viewModel.processVideo()
                }) {
                    HStack {
                        Image(systemName: "scissors")
                        Text("Crop + Frame")
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(viewModel.isProcessing || !viewModel.isFFmpegInstalled || viewModel.droppedVideoURL == nil || viewModel.selectedFrameURL == nil)

                Button(action: {
                    if let url = viewModel.processedVideoURL {
                        viewModel.revealInFinder(url: url)
                    }
                }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Reveal in Finder")
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(viewModel.processedVideoURL == nil)
            }
            .padding()

            if viewModel.isProcessing {
                ProgressView()
                    .padding()
            }

            if let error = viewModel.processingError {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.bottom, 8)
            }

            // Video Preview Section
            if let processedURL = viewModel.processedVideoURL {
                VStack(spacing: 8) {
                    Text("Processed Video Preview")
                        .font(.headline)
                        .padding(.top, 12)
                    VideoPlayer(player: AVPlayer(url: processedURL))
                        .frame(height: 340)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(18)
                        .shadow(radius: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.accentColor.opacity(0.2), lineWidth: 2)
                        )
                        .padding(.horizontal, 24)
                    Text(processedURL.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Selection Section
            HStack(alignment: .top, spacing: 32) {
                DropZone(title: "Drop Video File", url: $viewModel.droppedVideoURL)

                VStack {
                    Text("Select Frame")
                        .font(.headline)
                    Picker("Select a frame", selection: $viewModel.selectedFrameURL) {
                        ForEach(viewModel.availableFrames, id: \.self) { frameURL in
                            Text(frameURL.deletingPathExtension().lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .tag(frameURL as URL?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 320)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
            .padding()

            Spacer()
        }
        .frame(minWidth: 600, minHeight: 400)
        .padding()
        .onAppear {
            viewModel.checkForFFmpeg()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
