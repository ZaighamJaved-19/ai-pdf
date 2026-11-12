import '../sidecar_client/supervisor.dart';

class PdfEditorRepository {
  const PdfEditorRepository(this.sidecar);

  final SidecarSupervisor sidecar;

  Future<String> edit({
    required String inputPath,
    required String outputPath,
    List<Map<String, dynamic>> annotations = const [],
    List<Map<String, dynamic>> text = const [],
    List<Map<String, dynamic>> images = const [],
    Map<String, double>? crop,
    String? header,
    String? footer,
    String? watermark,
  }) async {
    final result = await sidecar.request('pdf.edit', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'annotations': annotations,
      'text': text,
      'images': images,
      if (crop != null) 'crop': crop,
      if (header != null && header.isNotEmpty) 'header': header,
      if (footer != null && footer.isNotEmpty) 'footer': footer,
      if (watermark != null && watermark.isNotEmpty) 'watermark': watermark,
    }) as Map<dynamic, dynamic>;
    return result['path'] as String;
  }

  Future<String> extractPages({
    required String inputPath,
    required String outputPath,
    required List<int> pages,
  }) async {
    final result = await sidecar.request('pdf.extractPages', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'pages': pages,
    }) as Map<dynamic, dynamic>;
    return result['path'] as String;
  }

  Future<String> transform({
    required String inputPath,
    required String outputPath,
    List<int>? order,
    Map<int, int> rotate = const {},
    List<int> delete = const [],
    List<int> duplicate = const [],
    List<int> blankAfter = const [],
  }) async {
    final result = await sidecar.request('pdf.transform', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      if (order != null) 'order': order,
      'rotate': rotate.map((key, value) => MapEntry(key.toString(), value)),
      'delete': delete,
      'duplicate': duplicate,
      'blankAfter': blankAfter,
    }) as Map<dynamic, dynamic>;
    return result['path'] as String;
  }

  Future<String> merge(List<String> inputPaths, String outputPath) async {
    final result = await sidecar.request('pdf.merge', {'inputPaths': inputPaths, 'outputPath': outputPath}) as Map<dynamic, dynamic>;
    return result['path'] as String;
  }

  Future<List<String>> split(String inputPath, String outputDirectory) async {
    final result = await sidecar.request('pdf.split', {'inputPath': inputPath, 'outputDirectory': outputDirectory}) as Map<dynamic, dynamic>;
    return (result['paths'] as List<dynamic>? ?? const []).cast<String>();
  }

  Future<String> compress(String inputPath, String outputPath) async {
    final result = await sidecar.request('pdf.compress', {'inputPath': inputPath, 'outputPath': outputPath}) as Map<dynamic, dynamic>;
    return result['path'] as String;
  }

  Future<String> protect({
    required String inputPath,
    required String outputPath,
    required String userPassword,
    String? ownerPassword,
    List<String> permissions = const [],
    bool use128Bit = true,
  }) async {
    final result = await sidecar.request('pdf.protect', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'userPassword': userPassword,
      if (ownerPassword != null && ownerPassword.isNotEmpty) 'ownerPassword': ownerPassword,
      'permissions': permissions,
      'use128Bit': use128Bit,
    }) as Map<dynamic, dynamic>;
    return result['path'] as String;
  }

  Future<String> removePassword(String inputPath, String outputPath, String password) async {
    final result = await sidecar.request('pdf.removePassword', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'password': password,
    }) as Map<dynamic, dynamic>;
    return result['path'] as String;
  }

  Future<String> removeMetadata(String inputPath, String outputPath) async {
    final result = await sidecar.request('pdf.removeMetadata', {
      'inputPath': inputPath,
      'outputPath': outputPath,
    }) as Map<dynamic, dynamic>;
    return result['path'] as String;
  }

  Future<String> redact({
    required String inputPath,
    required String outputPath,
    List<String> terms = const [],
    List<Map<String, dynamic>> regions = const [],
  }) async {
    final result = await sidecar.request('pdf.redact', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'terms': terms,
      'regions': regions,
    }) as Map<dynamic, dynamic>;
    return result['path'] as String;
  }

  Future<String> sign({
    required String inputPath,
    required String signaturePath,
    required String privateKeyPath,
    String? keyPassword,
  }) async {
    final result = await sidecar.request('pdf.sign', {
      'inputPath': inputPath,
      'signaturePath': signaturePath,
      'privateKeyPath': privateKeyPath,
      if (keyPassword != null && keyPassword.isNotEmpty) 'keyPassword': keyPassword,
    }) as Map<dynamic, dynamic>;
    return result['path'] as String;
  }

  Future<bool> validateSignature(String inputPath, String signaturePath) async {
    final result = await sidecar.request('pdf.validateSignature', {
      'inputPath': inputPath,
      'signaturePath': signaturePath,
    }) as Map<dynamic, dynamic>;
    return result['valid'] == true;
  }
}
