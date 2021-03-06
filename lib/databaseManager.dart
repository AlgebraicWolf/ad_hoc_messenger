import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:ad_hoc_messenger/utility/messages.dart';
import 'package:ad_hoc_messenger/utility/contact.dart';

class DatabaseManager {
  static final DatabaseManager _instance =
      DatabaseManager._privateConstructor();

  Database _db;

  Future<Database> get db async {
    if (_db != null) return _db;

    _db = await initDB();

    return _db;
  }

  factory DatabaseManager() {
    return _instance;
  }

  DatabaseManager._privateConstructor();

  bool isOpen() {
    return _db == null ? false : _db.isOpen;
  }

  Future<Database> initDB() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'ad_hoc_client.db');
    await openDatabase(path)
        .then((a) => a.close())
        .then((_) => deleteDatabase(path));

    var db = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db
            .execute(
                'CREATE TABLE IF NOT EXISTS Messages (otherHandle TEXT, text TEXT, sentAt TEXT, mine TEXT)')
            .then((_) => db.execute(
                'CREATE TABLE IF NOT EXISTS Contacts (handle TEXT, public_key TEXT, name TEXT)'))
            .then((_) => db.execute(
                'CREATE TABLE IF NOT EXISTS Keys (public_key TEXT, private_key TEXT, identity_key TEXT)'));
      },
    );

    return db;
  }

  Future<void> newMessage(ChatMessage msg) async {
    return db.then(
      (value) async {
        await value.rawInsert(
            'INSERT INTO Messages VALUES (\'${msg.otherHandle}\', \'${msg.text}\', \'${msg.sentAt.toString()}\', \'${msg.mine}\')');
      },
    );
  }

  Future<List<ChatMessage>> getCorrespondance(Contact contact) async {
    var database = await db;
    var records = await database.rawQuery(
        'SELECT * FROM Messages WHERE otherHandle = ?', ['${contact.handle}']);

    print('Received ${records.length} records from db');

    var messages = new Future<List<ChatMessage>>.value([]);
    for (var i = 0; i < records.length; i++) {
      messages.then((value) {
        value.add(
          ChatMessage(
            records[i]['otherHandle'] as String,
            records[i]['mine'] as String == 'true',
            records[i]['text'] as String,
            DateTime.parse(records[i]['sentAt'] as String),
          ),
        );
      });
    }

    return messages;
  }

  Future<List<Contact>> getUserContacts() async {
    var database = await db;
    var records = await database.query('Contacts');
    var contacts = new Future<List<Contact>>.value([]);
    for (var i = 0; i < records.length; i++) {
      contacts.then(
        (value) => value.add(
          Contact(
            records[i]['handle'] as String,
            records[i]['public_key'] as String,
            records[i]['name'] as String,
          ),
        ),
      );
    }

    return contacts;
  }

  void newContact(Contact contact) {
    db.then(
      (value) => value.rawInsert(
          'INSERT INTO Contacts VALUES (\'${contact.handle}\', \'${contact.publicKey}\', \'${contact.name}\')'),
    );
  }
}
