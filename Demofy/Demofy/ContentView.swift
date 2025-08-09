import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var viewModel = ViewModel()

    var body: some View {
        VStack {
            Text("Demofy")
                .font(.largeTitle)
                .padding()

            HStack(spacing: 20) {
                Button(action: {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.showSavePanelAndStartRecording()
                    }
                }) {
                    HStack {
                        if viewModel.isRecording {
                            Image(systemName: "record.circle.fill")
                                .foregroundColor(.red)
                        }
                        Text(viewModel.isRecording ? "Stop Recording" : "Record Simulator")
                    }
                    .frame(width: 150)
                }

                Button(action: {
                    viewModel.processVideo()
                }) {
                    Text("Crop + Frame")
                }
                .disabled(viewModel.isProcessing || !viewModel.isFFmpegInstalled || viewModel.droppedVideoURL == nil || viewModel.droppedFrameURL == nil)

                Button(action: {
                    if let url = viewModel.processedVideoURL {
                        viewModel.revealInFinder(url: url)
                    }
                }) {
                    Text("Reveal in Finder")
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
                    .padding()
            }

            if let videoURL = viewModel.videoURL {
                Text("Last recording: \(videoURL.path)")
                    .padding()
            }

            if let processedURL = viewModel.processedVideoURL {
                VideoPlayer(player: AVPlayer(url: processedURL))
                    .frame(height: 300)
                    .padding()

                Text("Processed video: \(processedURL.path)")
                    .padding(.bottom)
            }

            HStack(spacing: 20) {
                DropZone(title: "Drop Video File", url: $viewModel.droppedVideoURL)
                DropZone(title: "Drop Frame PNG", url: $viewModel.droppedFrameURL)
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
