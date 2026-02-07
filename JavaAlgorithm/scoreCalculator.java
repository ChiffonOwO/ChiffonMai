import java.io.BufferedInputStream;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Scanner;

public class scoreCalculator {
    public static void main(String[] args) {

        Scanner sc = new Scanner(new BufferedInputStream(System.in));

        // 定义各种note的权重
        int tap_weight = 1;
        int hold_weight = 2;
        int slide_weight = 3;
        int touch_weight = 1;
        int break_weight = 5;

        // 获取各种note的判定详情
        // critical_perfect
        System.out.println("CRITICAL PERFECT请按公众号上的判定详情表格顺序输入");
        int tap_critical_perfect = sc.nextInt();
        int hold_critical_perfect = sc.nextInt();
        int slide_critical_perfect = sc.nextInt();
        int touch_critical_perfect = sc.nextInt();
        int break_critical_perfect = sc.nextInt();

        // perfect
        System.out.println("PERFECT 前四项为请按公众号上的判定详情表格顺序输入，break依次为75%，50%");
        int tap_perfect = sc.nextInt();
        int hold_perfect = sc.nextInt();
        int slide_perfect = sc.nextInt();
        int touch_perfect = sc.nextInt();
        int break_perfect_75 = sc.nextInt(); // 额外评价中的75%
        int break_perfect_50 = sc.nextInt(); // 额外评价中的50%

        int break_perfect = break_perfect_50 + break_perfect_75;

        // great
        System.out.println("GREAT 前四项请按公众号上的判定详情表格顺序输入，break依次为80%，60%，50%");
        int tap_great = sc.nextInt();
        int hold_great = sc.nextInt();
        int slide_great = sc.nextInt();
        int touch_great = sc.nextInt();
        int break_great_80 = sc.nextInt(); //基础评价中的80%
        int break_great_60 = sc.nextInt(); //基础评价中的60%
        int break_great_50 = sc.nextInt(); //基础评价中的50%

        int break_great = break_great_80 + break_great_60 + break_great_50;

        // good
        System.out.println("GOOD 请按公众号上的判定详情表格顺序输入");
        int tap_good = sc.nextInt();
        int hold_good = sc.nextInt();
        int slide_good = sc.nextInt();
        int touch_good = sc.nextInt();
        int break_good = sc.nextInt();

        // miss
        System.out.println("MISS 请按公众号上的判定详情表格顺序输入");
        int tap_miss = sc.nextInt();
        int hold_miss = sc.nextInt();
        int slide_miss = sc.nextInt();
        int touch_miss = sc.nextInt();
        int break_miss = sc.nextInt();

        //计算音符总数
        int tap_num = tap_critical_perfect + tap_perfect + tap_great + tap_good + tap_miss;
        int hold_num = hold_critical_perfect + hold_perfect + hold_great + hold_good + hold_miss;
        int slide_num = slide_critical_perfect + slide_perfect + slide_great + slide_good + slide_miss;
        int touch_num = touch_critical_perfect + touch_perfect + touch_great +touch_good + touch_miss;
        int break_num = break_critical_perfect + break_perfect + break_great + break_good + break_miss;

        // 计算音符权重的总数
        int total_tap_weight = tap_num * tap_weight;
        int total_hold_weight = hold_num * hold_weight;
        int total_slide_weight = slide_num * slide_weight;
        int total_touch_weight = touch_num * touch_weight;
        int total_break_weight = break_num * break_weight;

        int total_weight =
                total_tap_weight + total_hold_weight + total_slide_weight + total_touch_weight + total_break_weight;

        // 计算基础评价部分 满分100
        double base_tap_weight =
                tap_weight * (tap_critical_perfect + tap_perfect + tap_great * 0.80 + tap_good * 0.50);
        double base_hold_weight =
                hold_weight * (hold_critical_perfect + hold_perfect + hold_great * 0.80 + hold_good * 0.50);
        double base_slide_weight =
                slide_weight * (slide_critical_perfect + slide_perfect + slide_great * 0.80 + slide_good * 0.50);
        double base_touch_weight =
                touch_weight * (touch_critical_perfect + touch_perfect + touch_great * 0.80 + touch_good * 0.50);
        double base_break_weight =
                break_weight * (break_critical_perfect + break_perfect + break_great_80 * 0.80
                        + break_great_60 * 0.60 + break_great_50 * 0.50 + break_good * 0.40);
        double base_weight =
                base_tap_weight + base_hold_weight + base_slide_weight + base_touch_weight + base_break_weight;

        BigDecimal base_weightBD = new BigDecimal(base_weight);
        BigDecimal total_weightBD = new BigDecimal(total_weight);
        BigDecimal score = null;

        try {
            //基础部分 满分100 结果四舍五入保留四位小数
            BigDecimal base_score = base_weightBD
                    .divide(total_weightBD, 10, RoundingMode.HALF_UP)
                    .multiply(new BigDecimal(100))
                    .setScale(4, RoundingMode.HALF_UP);

            // 计算额外评价部分 全由break决定 满分1 结果四舍五入保留四位小数
            double extra_break_weight =
                    break_critical_perfect + break_perfect_75 * 0.75 + break_perfect_50 * 0.50
                    + break_great * 0.40 + break_good * 0.30;
            BigDecimal extra_score = new BigDecimal(extra_break_weight)
                    .divide(new BigDecimal(break_num), 10, RoundingMode.HALF_UP)
                    .setScale(4, RoundingMode.HALF_UP);

            score = base_score.add(extra_score);

            System.out.println("基础达成率为" + base_score + "%");
            System.out.println("奖励达成率为" + extra_score + "%");
            System.out.println("达成率为：" + score + "%");
        } catch (ArithmeticException e) {
            // 处理除数为0的异常
            System.out.println("错误：除数不能为0");
        }

        sc.close();
    }
}
