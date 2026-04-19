import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const accent = Color(0xFF3A7BF7);
  static const background = Color(0xFFF5F5F7);
  static const cardBackground = Colors.white;
  static const recording = Color(0xFFFF3B30);
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9500);
  static const neutral = Color(0xFF8E8E93);
}

const String apiBaseUrl = 'https://www.nivowork.cn';

const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const List<String> industryOptions = ['企业服务', '消费文娱电商', '金融', '半导体', '信息科技', '材料', '能源', '制造'];

enum TemplateMode { classic, scenario, custom }

enum TemplateType {
  custom('自定义模板'),
  deep('深度纪要'),
  dialogue('对话式纪要'),
  keyPoints('关键点式纪要'),
  taskAssignment('任务分配');

  final String label;
  const TemplateType(this.label);
}

enum ScenarioType {
  pureRoadshow('纯路演'),
  roadshowQa('路演与问答'),
  ddInterview('尽调客户访谈'),
  postInvestment('投后管理');

  final String label;
  const ScenarioType(this.label);
}

enum AsrMode { auto, local }

/// 会后整理 / 结束会议时的转写方式
enum TranscribeMode { cloud, local }
