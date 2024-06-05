import 'dart:math';

import 'package:commanddash/agent/input_model.dart';
import 'package:commanddash/agent/output_model.dart';
import 'package:commanddash/agent/step_model.dart';
import 'package:commanddash/models/chat_message.dart';
import 'package:commanddash/models/data_source.dart';
import 'package:commanddash/repositories/dash_repository.dart';
import 'package:commanddash/repositories/generation_repository.dart';
import 'package:commanddash/server/task_assist.dart';
import 'package:commanddash/steps/append_to_chat/append_to_chat_step.dart';
import 'package:commanddash/steps/chat/chat_step.dart';
import 'package:commanddash/steps/find_closest_files/search_in_sources_step.dart';

class AgentHandler {
  final Map<String, Input> inputs;
  final Map<String, Output> outputs;
  final List<Map<String, dynamic>> steps;
  final GenerationRepository generationRepository;
  final String? githubAccessToken;
  final String agentName;
  final String agentVersion;
  final List<String> dataSources;
  final String? systemPrompt;

  String?
      userMessage; // This is last message used for chat mode. It is not useful for any command activated agent requests
  String? chatDocuments; // The attached documents so for in the chat mode

  /// Marks the agent as a test agent.
  final bool isTest;

  AgentHandler(
      {required this.inputs,
      required this.outputs,
      required this.steps,
      required this.generationRepository,
      required this.agentName,
      required this.agentVersion,
      this.githubAccessToken,
      this.dataSources = const [],
      this.systemPrompt,
      this.isTest = false,
      this.userMessage,
      this.chatDocuments});

  factory AgentHandler.fromJson(Map<String, dynamic> json) {
    final inputs = <String, Input>{};
    for (Map<String, dynamic> input in (json['registered_inputs'] as List)) {
      inputs.addAll({input['id']: Input.fromJson(input)});
    }
    final outputs = <String, Output>{};
    for (Map<String, dynamic> output
        in ((json['registered_outputs'] ?? []) as List)) {
      outputs.addAll({output['id']: Output.fromJson(output)});
    }
    final List<Map<String, dynamic>> steps =
        ((json['steps'] ?? []) as List).cast<Map<String, dynamic>>();

    final GenerationRepository generationRepository =
        GenerationRepository.fromJson(json['auth_details']);

    return AgentHandler(
        inputs: inputs,
        outputs: outputs,
        steps: steps,
        generationRepository: generationRepository,
        githubAccessToken: json['auth_details']['github_token'],
        agentName: json['agent_name'],
        agentVersion: json['agent_version'],
        isTest: json['testing'] ?? false,
        dataSources:
            ((json['chat_mode']?['data_sources'] ?? []) as List<dynamic>)
                .map((e) => e.toString())
                .toList(),
        systemPrompt: json['chat_mode']?['system_prompt'],
        userMessage: json['user_message'],
        chatDocuments: json['chat_documents']);
  }

  Future<void> runTask(TaskAssist taskAssist) async {
    DashRepository? dashRepository;
    if (githubAccessToken != null) {
      dashRepository = DashRepository.fromKeys(githubAccessToken!, taskAssist);
    }
    try {
      ///TODO: See if abstraction could be introduced
      if (steps.isEmpty) {
        await _handleChatRequest(taskAssist, dashRepository);
      } else {
        await _handleCommandRequest(taskAssist, dashRepository);
      }

      taskAssist.sendResultMessage(message: "TASK_COMPLETE", data: {});
    } catch (e, stackTrace) {
      taskAssist.sendErrorMessage(
          message: 'Error processing request: ${e.toString()}',
          data: {},
          stackTrace: stackTrace);
    }
  }

  Future<void> _handleChatRequest(
      TaskAssist taskAssist, DashRepository? dashRepository) async {
    if (userMessage == null) {
      taskAssist.sendErrorMessage(
          message: "User message is required for chat request", data: {});
      return;
    }
    final List<ChatMessage> messages =
        inputs.values.whereType<ChatQueryInput>().first.messages ?? [];
    final dataSources = this.dataSources.map((e) => DataSource(id: e)).toList();
    final SearchInSourceStep searchInSourceStep = SearchInSourceStep(
        outputIds: [],
        query: userMessage!,
        dataSource: dataSources,
        agentName: agentName,
        agentVersion: agentVersion,
        isTest: isTest);

    final searchResult = await searchInSourceStep.run(
        taskAssist, generationRepository, dashRepository);

    final ChatStep chatStep = ChatStep(
        outputIds: [],
        inputs: inputs,
        outputs: {},
        messages: messages,
        lastMessage: userMessage!,
        newDocuments: searchResult,
        existingDocuments: chatDocuments);

    final List<DefaultOutput> output =
        await chatStep.run(taskAssist, generationRepository, dashRepository);
    final AppendToChatStep appendToChatStep = AppendToChatStep(
      message: output.first.value ?? '',
    );
    await appendToChatStep.run(taskAssist, generationRepository);
  }

  Future<void> _handleCommandRequest(
      TaskAssist taskAssist, DashRepository? dashRepository) async {
    for (Map<String, dynamic> stepJson in steps) {
      try {
        final step = Step.fromJson(
            stepJson, inputs, outputs, agentName, agentVersion, isTest);
        final results =
            await step.run(taskAssist, generationRepository, dashRepository) ??
                [];
        if (step.outputIds != null) {
          if (results.isEmpty) {
            taskAssist.sendErrorMessage(
                message:
                    'No output received from the step where output was expected.',
                data: {});
          }
          for (int i = 0; i < results.length; i++) {
            final output = results[i];
            if (output is ContinueToNextStepOutput && !output.value) {
              break;
            } else {
              outputs[step.outputIds![i]] = output;
            }
          }
        }
      } catch (e, stackTrace) {
        taskAssist.sendErrorMessage(
            message:
                'Error processing step ${stepJson['type']}: ${e.toString()}',
            data: {},
            stackTrace: stackTrace);
      }
    }
  }
}
