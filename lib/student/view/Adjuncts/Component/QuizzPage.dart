// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:school_management_system/routes/app_pages.dart';
// import 'package:school_management_system/student/view/Adjuncts/Component/QuizBrain.dart';

// QuizBrain quizBrain = QuizBrain();

// class Quizzler extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade900,
//       body: SafeArea(
//         child: Padding(
//           padding: EdgeInsets.symmetric(horizontal: 10.0),
//           child: QuizPage(),
//         ),
//       ),
//     );
//   }
// }

// class QuizPage extends StatefulWidget {
//   QuizPage({this.id});
//   final id;
//   @override
//   _QuizPageState createState() => _QuizPageState();
// }

// class _QuizPageState extends State<QuizPage> {
//   List<Icon> scoreKeeper = [];

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder(
//       future: Future,
//       initialData: InitialData,
//       builder: (BuildContext context, AsyncSnapshot snapshot) {
//         return ;
//       },
//     ),
//   }

//   void checkAnswer(bool userPickedAnswer) {
//     bool correctAnswer = quizBrain.getCorrectAnswer();
//     setState(() {
//       if (quizBrain.isFinished()) {
//         Get.defaultDialog(
//             title: 'You End the quiz!',
//             onConfirm: () {
//               Get.toNamed(AppPages.tadjuncts.toString());
//             });
//         quizBrain.reset();
//         scoreKeeper = [];
//       } else {
//         if (userPickedAnswer == correctAnswer) {
//           scoreKeeper.add(Icon(Icons.check, color: Colors.green));
//         } else {
//           scoreKeeper.add(Icon(Icons.close, color: Colors.red));
//         }
//         quizBrain.nextQuestion();
//       }
//     });
//   }
// }
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:school_management_system/public/config/user_information.dart';
import 'package:school_management_system/public/utils/constant.dart';

class QuizzPage extends StatefulWidget {
	const QuizzPage({
		Key? key,
		required this.quizId,
		required this.name,
		required this.subject,
		required this.difficulty,
	}) : super(key: key);

	final String quizId;
	final String name;
	final String subject;
	final String difficulty;

	@override
	State<QuizzPage> createState() => _QuizzPageState();
}

class _QuizzPageState extends State<QuizzPage> {
	final TextEditingController _answerController = TextEditingController();
	Map<String, dynamic>? _quiz;
	bool _submitting = false;
	String? _resultMessage;

	@override
	void initState() {
		super.initState();
		_loadQuiz();
	}

	@override
	void dispose() {
		_answerController.dispose();
		super.dispose();
	}

	Future<void> _loadQuiz() async {
		final snapshot = await FirebaseFirestore.instance
				.collection('quiz')
				.where('uid', isEqualTo: widget.quizId)
				.limit(1)
				.get();

		if (snapshot.docs.isNotEmpty) {
			setState(() {
				_quiz = snapshot.docs.first.data();
			});
		}
	}

	Future<void> _submitAnswer() async {
		if (_answerController.text.trim().isEmpty || _quiz == null) {
			return;
		}
		setState(() {
			_submitting = true;
		});

		final answer = _answerController.text.trim();
		final correct = (_quiz!['answer'] ?? '').toString().trim();
		final isCorrect = answer.toLowerCase() == correct.toLowerCase();

		final docId = FirebaseFirestore.instance.collection('quiz-results').doc().id;
		await FirebaseFirestore.instance.collection('quiz-results').doc(docId).set({
			'uid': docId,
			'quiz_id': widget.quizId,
			'student_id': UserInformation.User_uId,
			'student_name': '${UserInformation.first_name} ${UserInformation.last_name}',
			'answer': answer,
			'correct_answer': correct,
			'is_correct': isCorrect,
			'submitted_at': Timestamp.now(),
			'subject_name': widget.subject,
			'quiz_name': widget.name,
		});

		setState(() {
			_submitting = false;
			_resultMessage = isCorrect
					? 'Correct answer. Great work!'
					: 'Submitted. Correct answer: $correct';
		});
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text(widget.name),
				backgroundColor: primaryColor,
				foregroundColor: Colors.white,
			),
			body: _quiz == null
					? const Center(child: CircularProgressIndicator())
					: Padding(
							padding: const EdgeInsets.all(16),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										widget.subject,
										style: const TextStyle(
											fontSize: 14,
											color: gray,
										),
									),
									const SizedBox(height: 8),
									Text(
										'Difficulty: ${widget.difficulty}',
										style: const TextStyle(
											fontSize: 14,
											color: gray,
										),
									),
									const SizedBox(height: 16),
									Text(
										(_quiz!['question'] ?? 'No question').toString(),
										style: const TextStyle(
											fontSize: 20,
											fontWeight: FontWeight.w700,
										),
									),
									const SizedBox(height: 20),
									TextField(
										controller: _answerController,
										decoration: InputDecoration(
											hintText: 'Type your answer',
											border: OutlineInputBorder(
												borderRadius: BorderRadius.circular(12),
											),
										),
									),
									const SizedBox(height: 16),
									SizedBox(
										width: double.infinity,
										child: ElevatedButton(
											onPressed: _submitting ? null : _submitAnswer,
											style: ElevatedButton.styleFrom(
												backgroundColor: primaryColor,
												foregroundColor: Colors.white,
											),
											child: _submitting
													? const SizedBox(
															height: 18,
															width: 18,
															child: CircularProgressIndicator(
																strokeWidth: 2,
																color: Colors.white,
															),
														)
													: const Text('Submit Answer'),
										),
									),
									const SizedBox(height: 12),
									if (_resultMessage != null)
										Text(
											_resultMessage!,
											style: TextStyle(
												color: _resultMessage!.startsWith('Correct')
														? Colors.green
														: Colors.orange,
												fontWeight: FontWeight.w600,
											),
										),
								],
							),
						),
		);
	}
}
