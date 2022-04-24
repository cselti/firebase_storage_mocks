import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:test/test.dart';

final imagefile = 'test/someimage.png';
final textfile = 'test/sometext.txt';

void main() {
  group('MockFirebaseStorage Tests', () {

    test('Puts File', () async {
      final storage = MockFirebaseStorage();
      final storageRef = storage.ref('test').child(imagefile.split('/')[1]);
      final image = File(imagefile);
      final task = storageRef.putFile(image);
      await task;

      expect(task.snapshot.ref.fullPath, equals('gs://some-bucket/$imagefile'));
      expect(storage.storedFilesMap.containsKey('$imagefile'), isTrue);
    });

    test('Puts Data', () async {
      final storage = MockFirebaseStorage();
      final storageRef = storage.ref('test').child(imagefile.split('/')[1]);
      final imageData = Uint8List(256);
      final task = storageRef.putData(imageData);
      await task;

      expect(task.snapshot.ref.fullPath, equals('gs://some-bucket/$imagefile'));
      expect(storage.storedDataMap.containsKey('$imagefile'), isTrue);
    });

    test('Gets Data', () async {
      final storage = MockFirebaseStorage();
      final storageRef = storage.ref().child(imagefile);
      final imageData = File(imagefile).readAsBytesSync();
      await storageRef.putData(imageData);
      final data = await storageRef.getData();
      expect(data, equals(imageData));
    });

    test('Writes file', () async {
      final storage = MockFirebaseStorage();
      final storageRef = storage.ref('test');
      final image = File(imagefile);
      final text = File(textfile);
      await storageRef.putFile(image);
      await storageRef.putFile(text);
      final targetImage = File('${Directory.systemTemp.path}/$imagefile');
      final targetText = File('${Directory.systemTemp.path}/$textfile');
      await storageRef.writeToFile(targetImage);
      await storageRef.writeToFile(targetText);
      expect(targetImage.existsSync(), isTrue);
      expect(targetText.existsSync(), isTrue);
      expect(targetText.readAsStringSync(), equals('Example test file'));
      targetImage.parent.deleteSync(recursive: true);
    });

    test('Get download url', () async {
      final storage = MockFirebaseStorage();
      final downloadUrl = await storage.ref('/some/path').getDownloadURL();
      expect(downloadUrl.startsWith('http'), isTrue);
      expect(downloadUrl.contains('/some/path'), isTrue);
    });

    test('Ref from url', () async {
      final storage = MockFirebaseStorage();
      final downloadUrl = await storage.ref('/some/path').getDownloadURL();
      final ref = storage.refFromURL(downloadUrl);
      expect(ref, isA<Reference>());
    });

    test('Set, get and update metadata', () async {
      final storage = MockFirebaseStorage();
      final storageRef = storage.ref().child(imagefile);
      final image = File(imagefile);
      final task = storageRef.putFile(image);
      await task;
      await storageRef.updateMetadata(SettableMetadata(
        cacheControl: 'public,max-age=300',
        contentType: 'image/png',
        customMetadata: <String, String>{
          'userId': 'ABC123',
        },
      ));

      final metadata = await storageRef.getMetadata();
      expect(metadata.cacheControl == 'public,max-age=300', true);
      expect(metadata.contentType == 'image/png', true);
      expect(metadata.customMetadata!['userId'] == 'ABC123', true);
      expect(metadata.name == storageRef.name, true);
      expect(metadata.fullPath == storageRef.fullPath, true);
      expect(metadata.timeCreated != null, true);

      await storageRef.updateMetadata(SettableMetadata(
        cacheControl: 'max-age=60',
        customMetadata: <String, String>{
          'userId': 'ABC123',
        },
      ));
      final metadata2 = await storageRef.getMetadata();
      expect(metadata2.cacheControl == 'max-age=60', true);
      ///Old informations persist over updates
      expect(metadata2.contentType == 'image/png', true);
    });
  });
}
