import 'package:commanddash/models/workspace_file.dart';
import 'package:commanddash/repositories/generation_repository.dart';
import 'package:commanddash/steps/find_closest_files/embedding_generator.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'embedding_generator_test.mocks.dart';

@GenerateMocks([GenerationRepository, WorkspaceFile])
void main() {
  group('updateEmbeddings', () {
    late MockGenerationRepository mockGenerationRepository;

    setUp(() {
      mockGenerationRepository = MockGenerationRepository();
    });

    test('should batch and update file embeddings < 100', () async {
      final files = List.generate(99, (i) {
        return WorkspaceFile('path/to/file$i.dart',
            content: 'content of file $i');
      });

      when(mockGenerationRepository
              .getCodeBatchEmbeddings(files.map((e) => e.content!).toList()))
          .thenAnswer((_) async =>
              files.map((e) => getMockEmbeddingForString(e.content!)).toList());

      final updatedFiles = await EmbeddingGenerator.updateEmbeddings(
          files, mockGenerationRepository);
      for (int i = 0; i < files.length; i++) {
        expect(updatedFiles[i].embedding,
            getMockEmbeddingForString(files[i].content!));
      }
      verify(mockGenerationRepository.getCodeBatchEmbeddings(any)).called(1);
    });
    test('should batch and update file embeddings > 100', () async {
      final files = List.generate(125, (i) {
        return WorkspaceFile('path/to/file$i.dart',
            content: 'content of file $i');
      });

      when(mockGenerationRepository.getCodeBatchEmbeddings(
              files.sublist(0, 100).map((e) => e.content!).toList()))
          .thenAnswer((_) async => files
              .sublist(0, 100)
              .map((e) => getMockEmbeddingForString(e.content!))
              .toList());
      when(mockGenerationRepository.getCodeBatchEmbeddings(
              files.sublist(100).map((e) => e.content!).toList()))
          .thenAnswer((_) async => files
              .sublist(100)
              .map((e) => getMockEmbeddingForString(e.content!))
              .toList());

      final updatedFiles = await EmbeddingGenerator.updateEmbeddings(
          files, mockGenerationRepository);
      for (int i = 0; i < files.length; i++) {
        expect(updatedFiles[i].embedding,
            getMockEmbeddingForString(files[i].content!));
      }
      verify(mockGenerationRepository.getCodeBatchEmbeddings(any)).called(2);
    });
    test('should batch and update file embeddings > 200', () async {
      final files = List.generate(250, (i) {
        return WorkspaceFile('path/to/file$i.dart',
            content: 'content of file $i');
      });

      when(mockGenerationRepository.getCodeBatchEmbeddings(
              files.sublist(0, 100).map((e) => e.content!).toList()))
          .thenAnswer((_) async => files
              .sublist(0, 100)
              .map((e) => getMockEmbeddingForString(e.content!))
              .toList());
      when(mockGenerationRepository.getCodeBatchEmbeddings(
              files.sublist(100, 200).map((e) => e.content!).toList()))
          .thenAnswer((_) async => files
              .sublist(100, 200)
              .map((e) => getMockEmbeddingForString(e.content!))
              .toList());
      when(mockGenerationRepository.getCodeBatchEmbeddings(
              files.sublist(200).map((e) => e.content!).toList()))
          .thenAnswer((_) async => files
              .sublist(200)
              .map((e) => getMockEmbeddingForString(e.content!))
              .toList());

      final updatedFiles = await EmbeddingGenerator.updateEmbeddings(
          files, mockGenerationRepository);
      for (int i = 0; i < files.length; i++) {
        expect(updatedFiles[i].embedding,
            getMockEmbeddingForString(files[i].content!));
      }
      verify(mockGenerationRepository.getCodeBatchEmbeddings(any)).called(3);
    });
  });
}

List<double> getMockEmbeddingForString(String value) {
  return value.codeUnits.map((e) => e.toDouble()).toList();
}
