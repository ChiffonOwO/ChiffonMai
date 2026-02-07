import java.io.BufferedInputStream;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Scanner;

public class ScoreFullReverseCalculator {
    // 定义权重常量
    private static final int TAP_WEIGHT = 1;
    private static final int HOLD_WEIGHT = 2;
    private static final int SLIDE_WEIGHT = 3;
    private static final int TOUCH_WEIGHT = 1;
    private static final int BREAK_WEIGHT = 5;

    public static void main(String[] args) {
        Scanner sc = new Scanner(new BufferedInputStream(System.in));

        // ========== 第一步：输入已知条件 ==========
        System.out.println("===== 输入已知条件 =====");
        // 1. 总达成率（满分101%，如100.5000）
        System.out.print("请输入总达成率（%）：");
        BigDecimal totalScoreTarget = sc.nextBigDecimal().setScale(4, RoundingMode.HALF_UP);

        // 2. 非break音符的所有判定总数（已知）
        System.out.println("\n===== 输入非break音符的判定总数（按顺序：critical_perfect, perfect, great, good, miss） =====");
        System.out.println("tap判定数：");
        int tapCp = sc.nextInt();
        int tapP = sc.nextInt();
        int tapG = sc.nextInt();
        int tapGo = sc.nextInt();
        int tapM = sc.nextInt();

        System.out.println("hold判定数：");
        int holdCp = sc.nextInt();
        int holdP = sc.nextInt();
        int holdG = sc.nextInt();
        int holdGo = sc.nextInt();
        int holdM = sc.nextInt();

        System.out.println("slide判定数：");
        int slideCp = sc.nextInt();
        int slideP = sc.nextInt();
        int slideG = sc.nextInt();
        int slideGo = sc.nextInt();
        int slideM = sc.nextInt();

        System.out.println("touch判定数：");
        int touchCp = sc.nextInt();
        int touchP = sc.nextInt();
        int touchG = sc.nextInt();
        int touchGo = sc.nextInt();
        int touchM = sc.nextInt();

        // 3. break音符的总数（仅总数，非细分）
        System.out.println("\n===== 输入break音符的总数（按顺序：critical_perfect, perfect, great, good, miss）=====");
        int breakCp = sc.nextInt();
        int breakPTotal = sc.nextInt();
        int breakGTotal = sc.nextInt();
        int breakGo = sc.nextInt();
        int breakM = sc.nextInt();

        // ========== 第二步：计算固定参数 ==========
        // 1. 计算非break音符的总数和基础得分
        int tapNum = tapCp + tapP + tapG + tapGo + tapM;
        int holdNum = holdCp + holdP + holdG + holdGo + holdM;
        int slideNum = slideCp + slideP + slideG + slideGo + slideM;
        int touchNum = touchCp + touchP + touchG + touchGo + touchM;
        int breakNum = breakCp + breakPTotal + breakGTotal + breakGo + breakM;

        // 总权重
        int totalTapWeight = tapNum * TAP_WEIGHT;
        int totalHoldWeight = holdNum * HOLD_WEIGHT;
        int totalSlideWeight = slideNum * SLIDE_WEIGHT;
        int totalTouchWeight = touchNum * TOUCH_WEIGHT;
        int totalBreakWeight = breakNum * BREAK_WEIGHT;
        int totalWeight = totalTapWeight + totalHoldWeight + totalSlideWeight + totalTouchWeight + totalBreakWeight;

        // 非break部分的基础得分（固定值）
        double baseTap = TAP_WEIGHT * (tapCp + tapP + tapG * 0.8 + tapGo * 0.5);
        double baseHold = HOLD_WEIGHT * (holdCp + holdP + holdG * 0.8 + holdGo * 0.5);
        double baseSlide = SLIDE_WEIGHT * (slideCp + slideP + slideG * 0.8 + slideGo * 0.5);
        double baseTouch = TOUCH_WEIGHT * (touchCp + touchP + touchG * 0.8 + touchGo * 0.5);
        double baseNonBreak = baseTap + baseHold + baseSlide + baseTouch;

        // ========== 第三步：遍历寻找可行解 ==========
        System.out.println("\n===== 开始反推可行解（误差≤0.0001%） =====");
        boolean found = false;
        BigDecimal errorThreshold = new BigDecimal("0.0001"); // 误差阈值

        // 遍历break_perfect_75的可能值（0~breakPTotal）
        for (int breakP75 = 0; breakP75 <= breakPTotal; breakP75++) {
            int breakP50 = breakPTotal - breakP75;

            // 遍历break_great_80的可能值（0~breakGTotal）
            for (int breakG80 = 0; breakG80 <= breakGTotal; breakG80++) {
                // 遍历break_great_60的可能值（0~剩余数量）
                for (int breakG60 = 0; breakG60 <= breakGTotal - breakG80; breakG60++) {
                    int breakG50 = breakGTotal - breakG80 - breakG60;

                    // 计算当前组合的基础达成率和额外达成率
                    // 1. 计算基础达成率
                    double baseBreak = BREAK_WEIGHT * (
                            breakCp + breakPTotal +
                                    breakG80 * 0.8 + breakG60 * 0.6 + breakG50 * 0.5 +
                                    breakGo * 0.4
                    );
                    double baseTotal = baseNonBreak + baseBreak;
                    BigDecimal baseScore = new BigDecimal(baseTotal)
                            .divide(new BigDecimal(totalWeight), 10, RoundingMode.HALF_UP)
                            .multiply(new BigDecimal(100))
                            .setScale(4, RoundingMode.HALF_UP);

                    // 2. 计算额外达成率
                    double extraBreak = breakCp + breakP75 * 0.75 + breakP50 * 0.5 +
                            breakGTotal * 0.4 + breakGo * 0.3;
                    BigDecimal extraScore = breakNum == 0 ? BigDecimal.ZERO :
                            new BigDecimal(extraBreak)
                                    .divide(new BigDecimal(breakNum), 10, RoundingMode.HALF_UP)
                                    .setScale(4, RoundingMode.HALF_UP);

                    // 3. 计算总达成率并对比目标值
                    BigDecimal totalScore = baseScore.add(extraScore).setScale(4, RoundingMode.HALF_UP);
                    BigDecimal error = totalScore.subtract(totalScoreTarget).abs();

                    // 找到符合误差阈值的解
                    if (error.compareTo(errorThreshold) <= 0) {
                        System.out.println("✅ 找到可行解：");
                        System.out.println("50落 = " + breakP75);
                        System.out.println("100落 = " + breakP50);
                        System.out.println("80% GREAT = " + breakG80);
                        System.out.println("60% GREAT = " + breakG60);
                        System.out.println("50% GREAT = " + breakG50);
                        System.out.println("计算出的基础达成率：" + baseScore + "%");
                        System.out.println("计算出的额外达成率：" + extraScore + "%");
                        System.out.println("计算出的总达成率：" + totalScore + "%（目标值：" + totalScoreTarget + "%）");
                        System.out.println("误差：" + error + "%");
                        found = true;
                        // 找到第一个解后退出（如需所有解可注释break）
                        break;
                    }
                }
                if (found) break;
            }
            if (found) break;
        }

        if (!found) {
            System.out.println("❌ 未找到符合误差阈值的解，以下是最接近的结果：");
            findClosestSolution(totalScoreTarget, baseNonBreak, totalWeight, breakCp, breakPTotal, breakGTotal, breakGo, breakNum);
        }

        sc.close();
    }

    /**
     * 寻找最接近目标达成率的解（无精确解时调用）
     */
    private static void findClosestSolution(BigDecimal target, double baseNonBreak, int totalWeight,
                                            int breakCp, int breakPTotal, int breakGTotal, int breakGo, int breakNum) {
        BigDecimal minError = new BigDecimal(Double.MAX_VALUE);
        int bestP75 = 0, bestP50 = 0, bestG80 = 0, bestG60 = 0, bestG50 = 0;
        BigDecimal bestBase = BigDecimal.ZERO, bestExtra = BigDecimal.ZERO, bestTotal = BigDecimal.ZERO;

        for (int breakP75 = 0; breakP75 <= breakPTotal; breakP75++) {
            int breakP50 = breakPTotal - breakP75;
            for (int breakG80 = 0; breakG80 <= breakGTotal; breakG80++) {
                for (int breakG60 = 0; breakG60 <= breakGTotal - breakG80; breakG60++) {
                    int breakG50 = breakGTotal - breakG80 - breakG60;

                    // 计算当前组合的达成率
                    double baseBreak = BREAK_WEIGHT * (
                            breakCp + breakPTotal +
                                    breakG80 * 0.8 + breakG60 * 0.6 + breakG50 * 0.5 +
                                    breakGo * 0.4
                    );
                    double baseTotal = baseNonBreak + baseBreak;
                    BigDecimal baseScore = new BigDecimal(baseTotal)
                            .divide(new BigDecimal(totalWeight), 10, RoundingMode.HALF_UP)
                            .multiply(new BigDecimal(100))
                            .setScale(4, RoundingMode.HALF_UP);

                    double extraBreak = breakCp + breakP75 * 0.75 + breakP50 * 0.5 +
                            breakGTotal * 0.4 + breakGo * 0.3;
                    BigDecimal extraScore = breakNum == 0 ? BigDecimal.ZERO :
                            new BigDecimal(extraBreak)
                                    .divide(new BigDecimal(breakNum), 10, RoundingMode.HALF_UP)
                                    .setScale(4, RoundingMode.HALF_UP);

                    BigDecimal totalScore = baseScore.add(extraScore).setScale(4, RoundingMode.HALF_UP);
                    BigDecimal error = totalScore.subtract(target).abs();

                    // 更新最接近的解
                    if (error.compareTo(minError) < 0) {
                        minError = error;
                        bestP75 = breakP75;
                        bestP50 = breakP50;
                        bestG80 = breakG80;
                        bestG60 = breakG60;
                        bestG50 = breakG50;
                        bestBase = baseScore;
                        bestExtra = extraScore;
                        bestTotal = totalScore;
                    }
                }
            }
        }

        // 输出最接近的解
        System.out.println("break_perfect_75 = " + bestP75);
        System.out.println("break_perfect_50 = " + bestP50);
        System.out.println("break_great_80 = " + bestG80);
        System.out.println("break_great_60 = " + bestG60);
        System.out.println("break_great_50 = " + bestG50);
        System.out.println("基础达成率：" + bestBase + "%");
        System.out.println("额外达成率：" + bestExtra + "%");
        System.out.println("总达成率：" + bestTotal + "%（目标值：" + target + "%）");
        System.out.println("最小误差：" + minError + "%");
    }
}