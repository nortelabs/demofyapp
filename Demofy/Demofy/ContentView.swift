import SwiftUI
import AVKit
import AspectFillVideoPlayer

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
                    viewModel.showSavePanelForProcessedVideo { outputURL in
                        guard let url = outputURL else { return }
                        viewModel.processVideo(outputURL: url)
                    }
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

            ZStack {
                // Input View
                VStack {
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
                .opacity(viewModel.processedVideoURL == nil ? 1 : 0)
                .disabled(viewModel.processedVideoURL != nil)

                // Video Preview
                VStack(spacing: 8) {
                    HStack(alignment: .center, spacing: 16) {
                        Text("Processed Video Preview")
                            .font(.headline)
                            .padding(.top, 12)
                        Spacer()
                        Button(action: { viewModel.reset() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Start Over")
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.top, 8)
                    }
                    AspectFillVideoPlayer(player: AVPlayer(url: viewModel.processedVideoURL ?? URL(fileURLWithPath: "/dev/null")))
                        .frame(maxWidth: .infinity, minHeight: 320, maxHeight: 600)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(18)
                        .shadow(radius: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.accentColor.opacity(0.2), lineWidth: 2)
                        )
                        .padding(.horizontal, 24)
                    Text(viewModel.processedVideoURL?.lastPathComponent ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 32)
                .opacity(viewModel.processedVideoURL != nil ? 1 : 0)
                .disabled(viewModel.processedVideoURL == nil)
            }
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
