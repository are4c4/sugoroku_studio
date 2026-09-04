import 'package:flutter/material.dart';

import 'data/local_course_repository.dart';
import 'presentation/course_list_screen.dart';

class SugorokuStudioApp extends StatefulWidget {
  const SugorokuStudioApp({super.key});

  @override
  State<SugorokuStudioApp> createState() => _SugorokuStudioAppState();
}

class _SugorokuStudioAppState extends State<SugorokuStudioApp> {
  final LocalCourseRepository _repository = LocalCourseRepository();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sugoroku Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: CourseListScreen(repository: _repository),
    );
  }
}
