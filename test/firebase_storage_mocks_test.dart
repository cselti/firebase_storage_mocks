import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
      await storageRef.putFile(File(imagefile));
      await storageRef.putFile(File(textfile));
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
      final storage = MockFirebaseStorage(calculateMd5Hash: true);
      final storageRef = storage.ref().child(imagefile);
      final image = File(imagefile);
      await storageRef.putFile(image);
      final now = DateTime.now();
      await storageRef.updateMetadata(SettableMetadata(
        cacheControl: 'public,max-age=300',
        contentType: 'image/png',
        customMetadata: <String, String>{
          'userId': 'ABC123',
        },
      ));

      final metadata = await storageRef.getMetadata();
      expect(metadata.cacheControl, equals('public,max-age=300'));
      expect(metadata.contentType, equals('image/png'));
      expect(metadata.customMetadata!['userId'], equals('ABC123'));
      expect(metadata.updated, isNotNull);
      expect(metadata.name, equals(storageRef.name));
      expect(metadata.fullPath, equals(storageRef.fullPath));
      expect(metadata.timeCreated, isNotNull);
      expect(metadata.md5Hash, equals((await md5.bind(File(imagefile).openRead()).first).toString()));

      await storageRef.updateMetadata(SettableMetadata(
        cacheControl: 'max-age=60',
        customMetadata: <String, String>{
          'userId': 'ABC123',
          'md5Hash': '12345',
          'creationTimeMillis': '${now.millisecondsSinceEpoch}',
          'updatedTimeMillis': '${now.millisecondsSinceEpoch}',
        },
      ));
      final metadata2 = await storageRef.getMetadata();

      expect(metadata2.cacheControl, equals('max-age=60'));
      expect(metadata2.contentType, equals('image/png'));
      expect(metadata2.md5Hash, equals('12345'));
      expect(metadata2.timeCreated, equals(DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch)));
      expect(metadata2.updated, equals(DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch)));
    });

    test('Throws error on download', () async {
      final storage = MockFirebaseStorage(throwsDownloadException: true);
      var storageRef = storage.ref('test').child(imagefile.split('/')[1]);
      final imageData = Uint8List(256);
      await storageRef.putData(imageData);
      expect(() async => await storageRef.getData(), throwsException);
      storageRef = storage.ref('test');
      await storageRef.putFile(File(imagefile));
      final targetImage = File('${Directory.systemTemp.path}/$imagefile');
      expect(() async => await storageRef.writeToFile(targetImage), throwsException);
    });
  });
}
