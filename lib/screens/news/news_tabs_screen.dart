import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/article_model.dart';
import '../../services/rss_service.dart';
import 'article_detail_screen.dart';
import '../social/nearby_map_screen.dart';
import '../auth/login_register_screen.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final RssService _rssService = RssService();
  late Future<List<Article>> _futureArticles;

  static const String _demoUserId = 'demo_user_1';

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _futureArticles = _rssService.fetchArticles();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {});
    });
  }

  Future<void> _signInAnonymously() async {
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      final uid = cred.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          <String, dynamic>{
            'name': 'User_$uid',
            'study_status': 'Chưa cập nhật',
          },
          SetOptions(merge: true),
        );
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sign-in failed: $e'),
      ));
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    setState(() {});
  }

  Future<void> _refresh() async {
    setState(() {
      _futureArticles = _rssService.fetchArticles();
    });
  }

  Future<void> _openNearbyMap() async {
    // Ensure user exists; sign in anonymously if not.
    String uid = _demoUserId;
    if (_currentUser == null) {
      await _signInAnonymously();
    }
    uid = FirebaseAuth.instance.currentUser?.uid ?? _demoUserId;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NearbyMapScreen(
          currentUserId: uid,
        ),
      ),
    );

    // Update Firestore doc for this user (async, non-blocking)
    FirebaseFirestore.instance.collection('users').doc(uid).set(
      <String, dynamic>{
        'name': 'Sinh viên Demo',
        'study_status': 'Đang ôn thi Toán',
      },
      SetOptions(merge: true),
    ).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật Firestore: $e')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily English News'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: _currentUser == null
                  ? TextButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                        );
                        setState(() {});
                      },
                      child: const Text('Đăng nhập / Đăng ký'),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                    )
                  : Row(
                      children: [
                        Text(
                          _currentUser!.isAnonymous ? 'Anonym' : (_currentUser!.email ?? 'You'),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout, color: Colors.white),
                        )
                      ],
                    ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNearbyMap,
        icon: const Icon(Icons.map),
        label: const Text('Nearby Study Map'),
      ),
      body: FutureBuilder<List<Article>>(
        future: _futureArticles,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                   const SizedBox(height: 16),
                   ElevatedButton(
                     onPressed: _refresh,
                     child: const Text('Retry'),
                   )
                 ],
               ),
             );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No articles found.'));
          }

          final articles = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final article = articles[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      article.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          article.pubDate,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArticleDetailScreen(article: article),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
