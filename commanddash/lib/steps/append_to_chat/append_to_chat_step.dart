import 'package:commanddash/agent/output_model.dart';
import 'package:commanddash/agent/step_model.dart';
import 'package:commanddash/repositories/generation_repository.dart';
import 'package:commanddash/server/task_assist.dart';
import 'package:commanddash/steps/steps_utils.dart';

class AppendToChatStep extends Step {
  final String message;

  AppendToChatStep({
    required String outputId,
    required this.message,
  }) : super(
          outputId: outputId,
          type: StepType.appendToChat,
        );

  factory AppendToChatStep.fromJson(
    Map<String, dynamic> json,
    String message,
  ) {
    return AppendToChatStep(
      outputId:
          '', //TODO[KEVAL]: Output ID shouldn't be mandatory for all steps
      message: message,
    );
  }

  @override
  Future<Output?> run(
      TaskAssist taskAssist, GenerationRepository generationRepository) async {
    final response = await taskAssist
        .processStep(kind: 'append_to_chat', args: {'message': message});
    if (response['error'] != null) {
      throw Exception(response['error']['message']);
    }
    return null;
  }
}
