import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:todofirebase/model/item_list.dart';
import 'package:todofirebase/model/todo.dart';
import 'package:todofirebase/view/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  FirebaseAuth auth = FirebaseAuth.instance;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  bool isComplete = false;

  Future<void> signOut() async {
    await auth.signOut();
    runApp(const MaterialApp(
      home: LoginPage(),
    ));
  }

  Future<QuerySnapshot>? searchResultsFuture;
  Future<void> searchResult(String textEntered) async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection("Todos")
        .where("title", isGreaterThanOrEqualTo: textEntered)
        .where("title", isLessThan: '${textEntered}z')
        .get();

    setState(() {
      searchResultsFuture = Future.value(querySnapshot);
    });
  }

  void cleartext() {
    titleController.clear();
    descriptionController.clear();
  }

  @override
  Widget build(BuildContext context) {
    CollectionReference todoCollection = firestore.collection('Todos');
    final User? user = auth.currentUser;

    Future<void> addTodo() {
      return todoCollection.add({
        'title': titleController.text,
        'description': descriptionController.text,
        'isComplete': isComplete,
        'uid': auth.currentUser!.uid,
        // ignore: invalid_return_type_for_catch_error
      }).catchError((error) => print('Failed to add todo: $error'));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Todo List'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Apakah anda yakin ingin logout?'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Tidak'),
                    ),
                    TextButton(
                      onPressed: () {
                        signOut();
                      },
                      child: const Text('Ya'),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            child: TextField(
              decoration: const InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder()),
              onChanged: (textEntered) {
                searchResult(textEntered);

                setState(() {
                  searchController.text = textEntered;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: searchController.text.isEmpty
                    ? firestore
                        .collection('Todos')
                        .where('uid', isEqualTo: user!.uid)
                        .snapshots()
                    : searchResultsFuture != null
                        ? searchResultsFuture!
                            .asStream()
                            .cast<QuerySnapshot<Map<String, dynamic>>>()
                        : const Stream.empty(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  List<Todo> listTodo = snapshot.data!.docs.map((document) {
                    final data = document.data();
                    final String title = data['title'];
                    final String description = data['description'];
                    final bool isComplete = data['isComplete'];
                    final String uid = user!.uid;

                    return Todo(
                        description: description,
                        title: title,
                        isComplete: isComplete,
                        uid: uid);
                  }).toList();
                  return ListView.builder(
                      shrinkWrap: true,
                      itemCount: listTodo.length,
                      itemBuilder: (context, index) {
                        return ItemList(
                          todo: listTodo[index],
                          transaksiDocId: snapshot.data!.docs[index].id,
                        );
                      });
                }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Tambah Todo'),
              content: SizedBox(
                width: 200,
                height: 100,
                child: Column(
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(hintText: 'Judul todo'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration:
                          const InputDecoration(hintText: 'Deskripsi todo'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Batalkan'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text('Tambah'),
                  onPressed: () {
                    addTodo();
                    cleartext();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
