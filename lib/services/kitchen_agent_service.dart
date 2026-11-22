import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/meal_plan.dart';
import '../models/pantry_item.dart';
import '../models/shopping_item.dart';
import 'hybrid_ai_service.dart';
import 'local_db_service.dart';

enum AgentActionType {
  none,
  timerStarted,
  shoppingAdded,
  pantryAdded,
  mealScheduled,
}

/// Represents the output of a Kitchen Agent execution.
class AgentResponse {
  final String spokenText;
  final String displayText;
  final AgentActionType actionType;
  final Map<String, dynamic> actionData;

  const AgentResponse({
    required this.spokenText,
    required this.displayText,
    this.actionType = AgentActionType.none,
    this.actionData = const {},
  });
}

/// Autonomous Kitchen Agent Dispatcher.
/// Orchestrates natural language (from Voice or Chatbot) into database actions,
/// timers, meal plans, and pan-side culinary guidance.
class KitchenAgentService {
  KitchenAgentService._();
  static final KitchenAgentService instance = KitchenAgentService._();

  final LocalDbService _db = LocalDbService.instance;
  final _uuid = const Uuid();

  /// Processes natural language input and autonomously executes actions.
  Future<AgentResponse> processCommand(
    String input, {
    String? recipeTitle,
    List<String>? ingredients,
    List<String>? directions,
  }) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) {
      return const AgentResponse(
        spokenText: "I didn't catch that.",
        displayText: "I didn't catch that. Ask a cooking question or set a timer.",
      );
    }

    final lower = cleanInput.toLowerCase();

    // ========================================================
    // 1. FAST LOCAL INTENTS (<10ms, 100% Offline, Zero Latency)
    // ========================================================

    // A. Timer Commands: e.g. "set timer for 10 minutes", "start 5 min timer"
    final timerRegex = RegExp(
      r'(?:set\s+)?(?:a\s+)?(?:timer\s+(?:for\s+)?)?(\d+)\s*(?:mins?|minutes?|secs?|seconds?)(?:\s+(?:for|timer))?(?:\s+(.*))?',
      caseSensitive: false,
    );
    if (lower.contains('timer')) {
      final match = timerRegex.firstMatch(cleanInput);
      if (match != null) {
        final mins = int.tryParse(match.group(1) ?? '5') ?? 5;
        final rawLabel = match.group(2)?.trim();
        final label = (rawLabel != null && rawLabel.isNotEmpty)
            ? rawLabel
            : (recipeTitle != null ? '$recipeTitle Timer' : 'Step Timer');

        return AgentResponse(
          spokenText: 'Starting your $mins minute timer for $label.',
          displayText: '⏱️ Started a **$mins minute** timer for **$label**.',
          actionType: AgentActionType.timerStarted,
          actionData: {'minutes': mins, 'label': label},
        );
      }
    }

    // B. Ingredient Recall during Cooking: e.g. "read ingredients", "how much garlic"
    if (ingredients != null && ingredients.isNotEmpty) {
      if (lower.contains('read ingredients') ||
          lower.contains('what are the ingredients') ||
          lower.contains('what do i need') ||
          lower.contains('list ingredients')) {
        final preview = ingredients.take(6).join(', ');
        return AgentResponse(
          spokenText: 'Here are the ingredients: $preview.',
          displayText: '### Recipe Ingredients:\n${ingredients.map((i) => "- $i").join("\n")}',
          actionType: AgentActionType.none,
        );
      }

      // Check specific ingredient query
      final inputWords = lower.split(RegExp(r'\s+'));
      for (final ing in ingredients) {
        final ingLower = ing.toLowerCase();
        for (final word in inputWords) {
          if (word.length >= 4 && ingLower.contains(word)) {
            return AgentResponse(
              spokenText: 'You need $ing.',
              displayText: '🥄 **Ingredient Detail**: $ing',
              actionType: AgentActionType.none,
            );
          }
        }
      }
    }

    // ========================================================
    // 2. HYBRID AI INTENT REASONING (Gemini Nano On-Device)
    // ========================================================
    final prompt = '''You are ChowGenie, an autonomous culinary agent running on Gemini Nano.
Analyze the user command. Decide whether it is an ACTION to execute, or a CULINARY QUESTION.
Active Recipe Context: ${recipeTitle ?? "None"}

If it is an ACTION, output ONLY a JSON object:
{"action": "timer", "minutes": 10, "label": "pasta"}
{"action": "shopping_add", "items": ["milk", "eggs"]}
{"action": "pantry_add", "name": "oat milk", "quantity": 1.0, "unit": "L", "category": "Dairy", "expiryDays": 7}
{"action": "meal_schedule", "recipeTitle": "Chicken Fajitas", "dayOffset": 1, "mealType": "dinner"}

If it is a CULINARY QUESTION or substitution (e.g. "Can I substitute butter?"), answer concisely in 1-2 practical sentences (plain text, NO JSON).

User Command: "$cleanInput"''';

    try {
      final result = await HybridAiService.instance.generateContent(prompt: prompt);
      var text = result.text.trim();

      // Strip markdown code fences if model returned them
      if (text.startsWith('```')) {
        text = text.replaceAll(RegExp(r'^```(json)?\n?'), '').replaceAll(RegExp(r'\n?```$'), '').trim();
      }

      if (text.startsWith('{') && text.endsWith('}')) {
        final Map<String, dynamic> map = jsonDecode(text);
        final action = map['action']?.toString();

        // 1. Timer Tool Execution
        if (action == 'timer') {
          final mins = (map['minutes'] as num?)?.toInt() ?? 5;
          final label = map['label']?.toString() ?? 'Cooking Timer';
          return AgentResponse(
            spokenText: 'Started $mins minute timer for $label.',
            displayText: '⏱️ Started a **$mins minute** timer for **$label**.',
            actionType: AgentActionType.timerStarted,
            actionData: {'minutes': mins, 'label': label},
          );
        }

        // 2. Shopping List Tool Execution
        if (action == 'shopping_add') {
          final itemsList = (map['items'] as List?)?.map((e) => e.toString().trim()).toList() ?? [];
          for (final item in itemsList) {
            if (item.isEmpty) continue;
            await _db.insertShoppingItem(ShoppingItem(
              id: _uuid.v4(),
              name: item,
              quantity: 1,
              unit: 'unit',
              source: ShoppingItemSource.manual,
              createdAt: DateTime.now(),
            ));
          }
          final count = itemsList.length;
          return AgentResponse(
            spokenText: 'Added $count items to your shopping list.',
            displayText: '🛒 Added **$count items** to your Shopping List:\n${itemsList.map((i) => "• $i").join("\n")}',
            actionType: AgentActionType.shoppingAdded,
            actionData: {'items': itemsList},
          );
        }

        // 3. Pantry Inventory Tool Execution
        if (action == 'pantry_add') {
          final name = map['name']?.toString().trim() ?? 'Food item';
          final qty = (map['quantity'] as num?)?.toDouble() ?? 1.0;
          final unit = map['unit']?.toString().trim() ?? 'unit';
          final cat = map['category']?.toString().trim() ?? 'Other';
          final days = (map['expiryDays'] as num?)?.toInt() ?? 7;

          await _db.insertPantryItem(PantryItem(
            id: _uuid.v4(),
            name: name,
            quantity: qty,
            unit: unit,
            category: cat,
            expiryDate: DateTime.now().add(Duration(days: days)),
            notes: 'Added via ChowGenie Agent',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));

          return AgentResponse(
            spokenText: 'Added $qty $unit of $name to your pantry.',
            displayText: '📦 Added **$qty $unit of $name** to your Pantry (Category: $cat).',
            actionType: AgentActionType.pantryAdded,
            actionData: {'name': name, 'quantity': qty, 'unit': unit},
          );
        }

        // 4. Meal Planner Tool Execution
        if (action == 'meal_schedule') {
          final title = map['recipeTitle']?.toString().trim() ?? (recipeTitle ?? 'Planned Meal');
          final dayOffset = (map['dayOffset'] as num?)?.toInt() ?? 0;
          final mealTypeStr = map['mealType']?.toString().trim().toLowerCase() ?? 'dinner';
          final mealType = MealType.values.firstWhere(
            (m) => m.name == mealTypeStr,
            orElse: () => MealType.dinner,
          );
          final scheduledDate = DateTime.now().add(Duration(days: dayOffset));

          await _db.insertMealPlanEntry(MealPlanEntry(
            id: _uuid.v4(),
            recipeId: '',
            recipeTitle: title,
            mealType: mealType,
            date: scheduledDate,
            servings: 2,
          ));

          final dayName = dayOffset == 0 ? 'Today' : (dayOffset == 1 ? 'Tomorrow' : 'in $dayOffset days');
          return AgentResponse(
            spokenText: 'Scheduled $title for $dayName\'s ${mealType.name}.',
            displayText: '📅 Scheduled **$title** for **$dayName\'s ${mealType.name}**.',
            actionType: AgentActionType.mealScheduled,
            actionData: {'title': title, 'date': scheduledDate.toIso8601String()},
          );
        }
      }

      // Plain culinary advice or substitution response
      return AgentResponse(
        spokenText: text,
        displayText: text,
        actionType: AgentActionType.none,
      );
    } catch (_) {
      return AgentResponse(
        spokenText: 'I am your kitchen assistant for recipes, timers, and groceries.',
        displayText: 'I can help adjust timers, add groceries, or answer cooking questions.',
        actionType: AgentActionType.none,
      );
    }
  }
}
