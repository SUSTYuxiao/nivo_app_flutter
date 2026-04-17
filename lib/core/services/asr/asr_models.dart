/// ASR model type for sherpa-onnx config dispatch.
enum AsrModelType { paraformer, qwen3 }

/// Metadata for an on-device ASR model.
class AsrModelInfo {
  final String id;
  final String name;
  final String sizeLabel;
  final String description;
  final List<String> files;
  final String baseUrl;
  final AsrModelType modelType;
  final bool isRecommended;
  final bool isAvailable;

  const AsrModelInfo({
    required this.id,
    required this.name,
    required this.sizeLabel,
    required this.description,
    required this.files,
    required this.baseUrl,
    required this.modelType,
    this.isRecommended = false,
    this.isAvailable = true,
  });
}

/// Available on-device ASR models.
const kAsrModels = [
  AsrModelInfo(
    id: 'paraformer-zh',
    name: 'Paraformer 中文',
    sizeLabel: '~220MB',
    description: '阿里达摩院，中文普通话，通用稳定',
    files: ['model.int8.onnx', 'tokens.txt'],
    baseUrl:
        'https://hf-mirror.com/csukuangfj/sherpa-onnx-paraformer-zh-2023-09-14/resolve/main',
    modelType: AsrModelType.paraformer,
  ),
  AsrModelInfo(
    id: 'qwen3-asr',
    name: 'Qwen3-ASR',
    sizeLabel: '~900MB',
    description: '阿里Qwen团队，28语言+中文方言，精度最高',
    files: [
      'model_0.6B/conv_frontend.onnx',
      'model_0.6B/encoder.int8.onnx',
      'model_0.6B/decoder.int8.onnx',
      'tokenizer/tokenizer_config.json',
      'tokenizer/vocab.json',
      'tokenizer/merges.txt',
    ],
    baseUrl:
        'https://modelscope.cn/models/zengshuishui/Qwen3-ASR-onnx/resolve/master',
    modelType: AsrModelType.qwen3,
    isRecommended: true,
    isAvailable: true,
  ),
];
