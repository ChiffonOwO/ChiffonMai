class DetailedJudgement {
  // tap
  final int tapCP;
  final int tapPERFECT;
  final int tapGREAT;
  final int tapGOOD;
  final int tapMISS;

  // hold
  final int holdCP;
  final int holdPERFECT;
  final int holdGREAT;
  final int holdGOOD;
  final int holdMISS;

  // slide
  final int slideCP;
  final int slidePERFECT;
  final int slideGREAT;
  final int slideGOOD;
  final int slideMISS;

  // touch
  final int touchCP;
  final int touchPERFECT;
  final int touchGREAT;
  final int touchGOOD;
  final int touchMISS;

  // break
  final int breakCP;
  final int break50LuoPERFECT; // 50落
  final int break100LuoPERFECT; // 100落
  final int break80GREAT; // 80% GREAT
  final int break60GREAT; // 60% GREAT
  final int break50GREAT; // 50% GREAT
  final int breakGOOD;
  final int breakMISS;

  DetailedJudgement({
    required this.tapCP,
    required this.tapPERFECT,
    required this.tapGREAT,
    required this.tapGOOD,
    required this.tapMISS,
    required this.holdCP,
    required this.holdPERFECT,
    required this.holdGREAT,
    required this.holdGOOD,
    required this.holdMISS,
    required this.slideCP,
    required this.slidePERFECT,
    required this.slideGREAT,
    required this.slideGOOD,
    required this.slideMISS,
    required this.touchCP,
    required this.touchPERFECT,
    required this.touchGREAT,
    required this.touchGOOD,
    required this.touchMISS,
    required this.breakCP,
    required this.break50LuoPERFECT,
    required this.break100LuoPERFECT,
    required this.break80GREAT,
    required this.break60GREAT,
    required this.break50GREAT,
    required this.breakGOOD,
    required this.breakMISS,
  });

  int getTotalTap() => tapCP + tapPERFECT + tapGREAT + tapGOOD + tapMISS;
  int getTotalHold() => holdCP + holdPERFECT + holdGREAT + holdGOOD + holdMISS;
  int getTotalSlide() => slideCP + slidePERFECT + slideGREAT + slideGOOD + slideMISS;
  int getTotalTouch() => touchCP + touchPERFECT + touchGREAT + touchGOOD + touchMISS;
  int getTotalBreak() => breakCP + break50LuoPERFECT + break100LuoPERFECT + break80GREAT + break60GREAT + break50GREAT + breakGOOD + breakMISS;
  int getTotal() => getTotalTap() + getTotalHold() + getTotalSlide() + getTotalTouch() + getTotalBreak();

  int getTotalCP() => tapCP + holdCP + slideCP + touchCP + breakCP;
  int getTotalPERFECT() => tapPERFECT + holdPERFECT + slidePERFECT + touchPERFECT + break50LuoPERFECT + break100LuoPERFECT;
  int getTotalGREAT() => tapGREAT + holdGREAT + slideGREAT + touchGREAT + break80GREAT + break60GREAT + break50GREAT;
  int getTotalGOOD() => tapGOOD + holdGOOD + slideGOOD + touchGOOD + breakGOOD;
  int getTotalMISS() => tapMISS + holdMISS + slideMISS + touchMISS + breakMISS;

  int getBreakTotalPERFECT() => break50LuoPERFECT + break100LuoPERFECT;
  int getBreakTotalGREAT() => break80GREAT + break60GREAT + break50GREAT;
  

  @override
String toString() {
  // 计算每行总数
  int tapTotal = getTotalTap();
  int holdTotal = getTotalHold();
  int slideTotal = getTotalSlide();
  int touchTotal = getTotalTouch();
  int breakTotal = getTotalBreak();

  // 计算总和列
  int sumCP = getTotalCP();
  int sumPERFECT = getTotalPERFECT();
  int sumGREAT = getTotalGREAT();
  int sumGOOD = getTotalGOOD();
  int sumMISS = getTotalMISS();
  int grandTotal = getTotal();  

  // 表格格式化输出（对齐美观）
  return '''
┌─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐
│ 类型     │ CP      │ PERFECT │ GREAT   │ GOOD    │ MISS    │ 合计     │
├─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
│ Tap     │ ${tapCP.toString().padLeft(7)} │ ${tapPERFECT.toString().padLeft(7)} │ ${tapGREAT.toString().padLeft(7)} │ ${tapGOOD.toString().padLeft(7)} │ ${tapMISS.toString().padLeft(7)} │ ${tapTotal.toString().padLeft(7)} │
│ Hold    │ ${holdCP.toString().padLeft(7)} │ ${holdPERFECT.toString().padLeft(7)} │ ${holdGREAT.toString().padLeft(7)} │ ${holdGOOD.toString().padLeft(7)} │ ${holdMISS.toString().padLeft(7)} │ ${holdTotal.toString().padLeft(7)} │
│ Slide   │ ${slideCP.toString().padLeft(7)} │ ${slidePERFECT.toString().padLeft(7)} │ ${slideGREAT.toString().padLeft(7)} │ ${slideGOOD.toString().padLeft(7)} │ ${slideMISS.toString().padLeft(7)} │ ${slideTotal.toString().padLeft(7)} │
│ Touch   │ ${touchCP.toString().padLeft(7)} │ ${touchPERFECT.toString().padLeft(7)} │ ${touchGREAT.toString().padLeft(7)} │ ${touchGOOD.toString().padLeft(7)} │ ${touchMISS.toString().padLeft(7)} │ ${touchTotal.toString().padLeft(7)} │
│ Break   │ ${breakCP.toString().padLeft(7)} │ ${getBreakTotalPERFECT.toString().padLeft(7)} │ ${getBreakTotalGREAT.toString().padLeft(7)} │ ${breakGOOD.toString().padLeft(7)} │ ${breakMISS.toString().padLeft(7)} │ ${breakTotal.toString().padLeft(7)} │
├─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
│ 总数    │ ${sumCP.toString().padLeft(7)} │ ${sumPERFECT.toString().padLeft(7)} │ ${sumGREAT.toString().padLeft(7)} │ ${sumGOOD.toString().padLeft(7)} │ ${sumMISS.toString().padLeft(7)} │ ${grandTotal.toString().padLeft(7)} │
└─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘
''';
}
 }
