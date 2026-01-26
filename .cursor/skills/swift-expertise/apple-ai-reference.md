# Apple AI Integration Reference

Detailed patterns for integrating Apple's AI and ML frameworks.

## Core ML Advanced Patterns

### Model Deployment Options

| Approach | Pros | Cons |
|----------|------|------|
| Bundled in app | Works offline, fast | Increases app size |
| On-demand resource | Smaller initial download | Requires download before use |
| CloudKit model hosting | Easy updates | Requires network |
| Create ML on-device | Personalized models | Training overhead |

### Async Model Loading

```swift
actor ModelManager {
    private var model: VNCoreMLModel?
    
    func getModel() async throws -> VNCoreMLModel {
        if let model { return model }
        
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        
        let compiled = try await MLModel.load(
            contentsOf: Bundle.main.url(forResource: "MyModel", withExtension: "mlmodelc")!,
            configuration: config
        )
        
        let visionModel = try VNCoreMLModel(for: compiled)
        self.model = visionModel
        return visionModel
    }
}
```

### Batch Processing

```swift
func classifyBatch(_ images: [CGImage]) async throws -> [[Classification]] {
    let model = try await modelManager.getModel()
    
    return try await withThrowingTaskGroup(of: (Int, [Classification]).self) { group in
        for (index, image) in images.enumerated() {
            group.addTask {
                let results = try await self.classify(image, with: model)
                return (index, results)
            }
        }
        
        var results = Array(repeating: [Classification](), count: images.count)
        for try await (index, classifications) in group {
            results[index] = classifications
        }
        return results
    }
}
```

## Vision Framework Patterns

### Real-time Video Analysis

```swift
class VideoAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let sequenceHandler = VNSequenceRequestHandler()
    private var trackingRequests: [VNTrackObjectRequest] = []
    
    func captureOutput(_ output: AVCaptureOutput, 
                       didOutput sampleBuffer: CMSampleBuffer, 
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let requests: [VNRequest] = [
            VNDetectFaceRectanglesRequest { request, error in
                self.handleFaces(request.results as? [VNFaceObservation])
            },
            VNRecognizeTextRequest { request, error in
                self.handleText(request.results as? [VNRecognizedTextObservation])
            }
        ]
        
        try? sequenceHandler.perform(requests, on: pixelBuffer)
    }
}
```

### Document Analysis

```swift
func analyzeDocument(_ image: CGImage) async throws -> DocumentAnalysis {
    let textRequest = VNRecognizeTextRequest()
    textRequest.recognitionLevel = .accurate
    textRequest.usesLanguageCorrection = true
    
    let barcodeRequest = VNDetectBarcodesRequest()
    let rectangleRequest = VNDetectRectanglesRequest()
    
    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([textRequest, barcodeRequest, rectangleRequest])
    
    return DocumentAnalysis(
        text: textRequest.results?.compactMap { $0.topCandidates(1).first?.string },
        barcodes: barcodeRequest.results?.compactMap { $0.payloadStringValue },
        rectangles: rectangleRequest.results?.map { $0.boundingBox }
    )
}
```

## Natural Language Advanced

### Custom NLP Pipelines

```swift
class TextAnalyzer {
    private let tagger: NLTagger
    
    init() {
        tagger = NLTagger(tagSchemes: [
            .lexicalClass,
            .nameType,
            .sentimentScore,
            .lemma
        ])
    }
    
    func analyze(_ text: String) -> TextAnalysis {
        tagger.string = text
        
        var entities: [Entity] = []
        var sentiments: [Double] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, 
                            unit: .word, 
                            scheme: .nameType) { tag, range in
            if let tag, tag != .otherWord {
                entities.append(Entity(
                    text: String(text[range]),
                    type: tag
                ))
            }
            return true
        }
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                            unit: .sentence,
                            scheme: .sentimentScore) { tag, _ in
            if let score = tag.flatMap({ Double($0.rawValue) }) {
                sentiments.append(score)
            }
            return true
        }
        
        return TextAnalysis(
            entities: entities,
            averageSentiment: sentiments.isEmpty ? 0 : sentiments.reduce(0, +) / Double(sentiments.count)
        )
    }
}
```

### Text Embeddings for Similarity

```swift
import NaturalLanguage

class SemanticSearch {
    private let embedding: NLEmbedding?
    
    init() {
        embedding = NLEmbedding.wordEmbedding(for: .english)
    }
    
    func findSimilar(to query: String, in candidates: [String], topK: Int = 5) -> [String] {
        guard let embedding else { return [] }
        
        let queryVector = averageVector(for: query)
        
        return candidates
            .map { (text: $0, similarity: cosineSimilarity(queryVector, averageVector(for: $0))) }
            .sorted { $0.similarity > $1.similarity }
            .prefix(topK)
            .map { $0.text }
    }
    
    private func averageVector(for text: String) -> [Double] {
        let words = text.lowercased().split(separator: " ").map(String.init)
        var vectors: [[Double]] = []
        
        for word in words {
            if let vector = embedding?.vector(for: word) {
                vectors.append(vector)
            }
        }
        
        guard !vectors.isEmpty else { return [] }
        return zip(vectors[0].indices, vectors).map { idx, _ in
            vectors.map { $0[idx] }.reduce(0, +) / Double(vectors.count)
        }
    }
}
```

## Speech Framework Patterns

### Live Transcription

```swift
class LiveTranscriber: ObservableObject {
    @Published var transcript = ""
    @Published var isListening = false
    
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @MainActor
    func startListening() throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                Task { @MainActor in
                    self?.transcript = result.bestTranscription.formattedString
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self?.stopListening()
                }
            }
        }
    }
    
    @MainActor
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }
}
```

## App Intents & Shortcuts

### Parameterized Intents

```swift
struct SearchItemsIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Items"
    static var description = IntentDescription("Search for items by keyword")
    
    @Parameter(title: "Search Query", description: "Keywords to search for")
    var query: String
    
    @Parameter(title: "Limit", default: 10)
    var limit: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Search for \(\.$query)") {
            \.$limit
        }
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let results = await ItemStore.shared.search(query, limit: limit)
        return .result(value: results.map(\.title))
    }
}
```

### App Shortcuts Provider

```swift
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SearchItemsIntent(),
            phrases: [
                "Search \(.applicationName) for \(\.$query)",
                "Find \(\.$query) in \(.applicationName)"
            ],
            shortTitle: "Search",
            systemImageName: "magnifyingglass"
        )
        
        AppShortcut(
            intent: OpenItemIntent(),
            phrases: [
                "Open \(\.$itemName) in \(.applicationName)"
            ],
            shortTitle: "Open Item",
            systemImageName: "doc"
        )
    }
}
```

## Performance Tips

1. **Use Neural Engine** - Set `computeUnits = .cpuAndNeuralEngine` for ML models
2. **Batch requests** - Process multiple images in one Vision request handler when possible
3. **Background processing** - Use `.userInitiated` QoS for ML tasks, not `.userInteractive`
4. **Model warmup** - Load and run a dummy prediction at app launch to warm the model
5. **Memory management** - Release large models when not in use, reload on demand
