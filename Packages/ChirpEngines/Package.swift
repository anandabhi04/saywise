// swift-tools-version: 6.0
import PackageDescription

// Version pins must match speech-swift's own pins, or the two cannot resolve together:
// it requires mlx-swift-lm exactly 3.31.4 and WhisperKit from this URL.
let package = Package(
    name: "ChirpEngines",
    platforms: [.macOS(.v15)],
    products: [.library(name: "ChirpEngines", targets: ["ChirpEngines"])],
    dependencies: [
        .package(path: "../ChirpCore"),
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "1.0.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", exact: "3.31.4"),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
        .package(url: "https://github.com/soniqo/speech-swift", revision: "511307a"),
    ],
    targets: [
        .target(
            name: "ChirpEngines",
            dependencies: [
                .product(name: "ChirpCore", package: "ChirpCore"),
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "Qwen3ASR", package: "speech-swift"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
