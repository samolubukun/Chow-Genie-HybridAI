import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import '../services/model_manager.dart';
import '../services/local_db_service.dart';
import '../models/model_status.dart';

class NutritionViewModel extends ChangeNotifier {
  final ModelManager _modelManager;
  final LocalDbService _db = LocalDbService.instance;
  final _uuid = const Uuid();

  Map<String, double> _dailyTotals = {};
  List<Map<String, dynamic>> _weeklyLogs = [];
  List<Map<String, dynamic>> _todayLogs = [];
  int _waterIntake = 0;
  String? _healthInsight;
  bool _isLoading = false;
  bool _isGeneratingInsight = false;
  DateTime _selectedDate = DateTime.now();

  Map<String, double> get dailyTotals => _dailyTotals;
  List<Map<String, dynamic>> get weeklyLogs => _weeklyLogs;
  List<Map<String, dynamic>> get todayLogs => _todayLogs;
  int get waterIntake => _waterIntake;
  String? get healthInsight => _healthInsight;
  bool get isLoading => _isLoading;
  bool get isGeneratingInsight => _isGeneratingInsight;
  DateTime get selectedDate => _selectedDate;

  NutritionViewModel(this._modelManager);

  Future<void> loadDay({DateTime? date}) async {
    _isLoading = true;
    notifyListeners();
    if (date != null) _selectedDate = date;
    _dailyTotals = await _db.getDailyTotals(_selectedDate);
    _todayLogs = await _db.getNutritionLogs(_selectedDate);
    _waterIntake = await _db.getWaterIntake(_selectedDate);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadWeek(DateTime weekStart) async {
    _weeklyLogs = await _db.getWeeklyLogs(weekStart);
    notifyListeners();
  }

  Future<void> logMeal({
    required String recipeTitle,
    double calories = 0,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
    double fiber = 0,
    String mealType = 'meal',
    String? imagePath,
    String? notes,
  }) async {
    await _db.logNutrition(
      id: _uuid.v4(),
      recipeTitle: recipeTitle,
      date: _selectedDate,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      mealType: mealType,
      imagePath: imagePath,
      notes: notes,
    );
    await loadDay();
  }

  Future<void> addWater() async {
    await _db.addWaterIntake(_selectedDate, 1);
    _waterIntake = await _db.getWaterIntake(_selectedDate);
    notifyListeners();
  }

  Future<String> generateInsight(UserProfile? profile, {int days = 7}) async {
    _isGeneratingInsight = true;
    _healthInsight = null;
    notifyListeners();

    try {
      final start = DateTime.now().subtract(Duration(days: days));
      final logs = await _db.getWeeklyLogs(start);

      if (logs.isEmpty) {
        _healthInsight = 'Not enough data for insights. Start logging your meals!';
        _isGeneratingInsight = false;
        notifyListeners();
        return _healthInsight!;
      }

      double avgCal = 0, avgPro = 0, avgCarb = 0, avgFat = 0, avgFib = 0;
      for (final log in logs) {
        avgCal += (log['calories'] ?? 0).toDouble();
        avgPro += (log['protein'] ?? 0).toDouble();
        avgCarb += (log['carbs'] ?? 0).toDouble();
        avgFat += (log['fat'] ?? 0).toDouble();
        avgFib += (log['fiber'] ?? 0).toDouble();
      }
      final count = logs.length;
      avgCal /= count; avgPro /= count; avgCarb /= count; avgFat /= count; avgFib /= count;

      String prompt = 'Act as a nutritionist. Analyze these weekly averages:\n';
      prompt += 'Calories: ${avgCal.toStringAsFixed(0)}/day\n';
      prompt += 'Protein: ${avgPro.toStringAsFixed(1)}g\n';
      prompt += 'Carbs: ${avgCarb.toStringAsFixed(1)}g\n';
      prompt += 'Fat: ${avgFat.toStringAsFixed(1)}g\n';
      prompt += 'Fiber: ${avgFib.toStringAsFixed(1)}g\n';

      if (profile != null) {
        prompt += '\nUser goals: ${profile.dailyCalorieGoal.toStringAsFixed(0)} cal, '
            'Protein ${profile.dailyProteinGoal.toStringAsFixed(0)}g, '
            'Carbs ${profile.dailyCarbsGoal.toStringAsFixed(0)}g, '
            'Fat ${profile.dailyFatGoal.toStringAsFixed(0)}g\n';
        if (profile.healthConditions.isNotEmpty) {
          prompt += 'Health conditions: ${profile.healthConditions.join(", ")}\n';
        }
      }

      prompt += '\nProvide 2-3 specific, actionable nutritional insights and recommendations.';

      final response = await _modelManager.generateResponse(prompt);
      _healthInsight = response ?? 'Could not generate insights.';
    } catch (e) {
      _healthInsight = 'Error generating insights.';
    }

    _isGeneratingInsight = false;
    notifyListeners();
    return _healthInsight ?? '';
  }
}
