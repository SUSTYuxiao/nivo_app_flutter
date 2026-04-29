import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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

/// Notion 风格 Markdown 样式，纪要展示统一复用
MarkdownStyleSheet nivoMarkdownStyle() => MarkdownStyleSheet(
      p: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF37352F)),
      h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF37352F)),
      h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF37352F)),
      h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF37352F)),
      listBullet: const TextStyle(fontSize: 14, color: Color(0xFF37352F)),
      blockquoteDecoration: BoxDecoration(
        border: const Border(left: BorderSide(color: Color(0xFFE9E9E7), width: 3)),
        color: const Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(2),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF7F6F3),
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE9E9E7))),
      ),
    );

/// 会后整理 / 结束会议时的转写方式
enum TranscribeMode { cloud, local }

/// 离线转写处理阶段
enum ProcessingStage {
  idle,
  preparing,         // getStsToken / 文件准备
  uploading,         // OSS 上传（有真实进度）
  cloudTranscribing, // 服务端转写（假进度）
  downloadingModel,  // 本地模型下载
  localTranscribing, // 本地转写（假进度）
  generating,        // LLM 生成纪要
  error,
}
