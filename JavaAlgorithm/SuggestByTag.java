package com.teen9g;

import java.util.ArrayList;
import java.util.List;
import java.util.Scanner;
import java.util.regex.Pattern;

public class SuggestByTag {

    // 正则：匹配 {数字} 或 (数字)
    private static final Pattern PATTERN_PLACEHOLDER = Pattern.compile("^\\{\\d+}$|^\\(\\d+\\)$");
    // 正则：匹配 &inote_num=数字
    private static final Pattern PATTERN_INOTE = Pattern.compile("^&inote_num=\\d+$");
    // 正则：匹配 (数字){数字} 形式，如 (216){1}
    private static final Pattern PATTERN_PARENTHESIS_BRACE = Pattern.compile("^\\(\\d+\\)\\{\\d+}$");
    // 正则：匹配 HOLD 模式，如 6h[4:1], Ch[4:3]
    private static final Pattern PATTERN_HOLD = Pattern.compile(".*h\\[\\d+:\\d+\\].*");
    // 正则：匹配 TOUCH 模式，如 E7, C1f
    private static final Pattern PATTERN_TOUCH = Pattern.compile(".*[A-G]\\d+f?.*");
    // 正则：匹配纯数字或数字x形式，如 1, 2, 1x, 2x
    private static final Pattern PATTERN_TAP = Pattern.compile("^\\d+x?$");
    // 正则：匹配修饰符（用于分割）
    private static final Pattern PATTERN_MODIFIERS = Pattern.compile("(?=[-<>^vpszwVpq]|pp|qq)");

    public static List<String> parseSlideSegments(String segment) {
        List<String> parts = new ArrayList<>();
        String[] splitParts = PATTERN_MODIFIERS.split(segment);
        
        boolean isFirst = true;
        for (String part : splitParts) {
            if (part.isEmpty()) continue;
            
            if (part.contains("[")) {
                parts.add(part);
                isFirst = false;
            } else if (isFirst) {
                parts.add(part);
                isFirst = false;
            }
        }
        return parts;
    }

    public static List<String> extractValidSegments(String text) {
        List<String> result = new ArrayList<>();

        // 1. 按逗号分割所有片段
        String[] segments = text.split(",");

        // 2. 遍历清洗
        for (String seg : segments) {
            // 去首尾空白
            String clean = seg.trim();

            // 移除开头的 {数字} 部分，如 {4}7x/8x -> 7x/8x
            clean = clean.replaceAll("^\\{\\d+}", "");

            // 跳过空
            if (clean.isEmpty()) continue;

            // 跳过 {数字} / (数字)
            if (PATTERN_PLACEHOLDER.matcher(clean).matches()) continue;

            // 跳过 (数字){数字} 形式
            if (PATTERN_PARENTHESIS_BRACE.matcher(clean).matches()) continue;

            // 跳过单独 E
            if ("E".equals(clean)) continue;

            // 跳过 &inote_num=数字
            if (PATTERN_INOTE.matcher(clean).matches()) continue;

            // 如果包含 / 则拆分
            if (clean.contains("/")) {
                String[] parts = clean.split("/");
                for (String part : parts) {
                    String trimmedPart = part.trim();
                    if (!trimmedPart.isEmpty()) {
                        processSegment(trimmedPart, result);
                    }
                }
            } else {
                processSegment(clean, result);
            }
        }

        return result;
    }

    private static void processSegment(String segment, List<String> result) {
        boolean hasModifier = segment.matches(".*[-<>^vpqszwV].*") || segment.contains("pp") || segment.contains("qq");
        
        if (hasModifier) {
            List<String> parsedParts = parseSlideSegments(segment);
            result.addAll(parsedParts);
        } else {
            result.add(segment);
        }
    }

    public static enum NoteType {
        TAP, HOLD, SLIDE, BREAK, TOUCH
    }

    private static final Pattern PATTERN_BRACKET = Pattern.compile(".*\\[.*\\].*");

    public static NoteType classifyNote(String note) {
        if (note.contains("b")) {
            return NoteType.BREAK;
        }
        if (PATTERN_HOLD.matcher(note).matches()) {
            return NoteType.HOLD;
        }
        if (PATTERN_TOUCH.matcher(note).matches()) {
            return NoteType.TOUCH;
        }
        if (PATTERN_TAP.matcher(note).matches()) {
            return NoteType.TAP;
        }
        if (PATTERN_BRACKET.matcher(note).matches()) {
            return NoteType.SLIDE;
        }
        System.err.println("[DEBUG] Unknown type: '" + note + "'");
        return NoteType.SLIDE;
    }

    public static int[] countNoteTypes(List<String> notes) {
        int[] counts = new int[NoteType.values().length];
        for (String note : notes) {
            NoteType type = classifyNote(note);
            counts[type.ordinal()]++;
        }
        return counts;
    }

    public static List<String>[] collectByType(List<String> notes) {
        List<String>[] result = new List[NoteType.values().length];
        for (int i = 0; i < result.length; i++) {
            result[i] = new ArrayList<>();
        }
        for (String note : notes) {
            NoteType type = classifyNote(note);
            result[type.ordinal()].add(note);
        }
        return result;
    }

    public static void main(String[] args) {
        String rawText = """
                (225){1},
                    {16},,,,,,,,1,8,1,8,1,8,1,8,
                    {32}1,,8,,1,,8,,1,,8,,1,,8,,1,,8,,1x,2x,3x,4x,5x,6x,7x,8x,1x,2x/7x,3x/6xpp5>5[16:39],4bxqq5<5[32:77],
                    {1}A5f,
                    {1},
                    {1},
                    {8}3,8,3,6,1,6,2,2,
                    {8}7,7,4,5,2,4,2,7,
                    {8}5,7,1/3,,6/8,,2/7,,
                    {32}1b/8b,2/7,6/3qq4>4[16:39],5bpp4<4[32:77],A4f,,,,,,,,,,,,,,,,,,,,,,,,,,,,
                    {1},
                    {1},
                    {8}7,5,7,3,5,3,6,4,
                    {8}6,2,4,2,6,5,7,5,
                    {8}8,8,3,4,2,4,1>1[4:3],5s1[8:5],
                    {1}A1f,
                    {8},,,,7x/2x-4[8:1],,2/5,6-8[8:1],
                    {8},5/6,4,,2,2,4,3,
                    {8}4/6-4[8:1],,3/6,2,1-5[8:1],8,7,,
                    {8}4/6h[4:1],,5pp1[2:1],4,3,,3,,
                    {8}2,2,1/2,,7h[4:1]/8,,4,6,
                    {8}2>4[8:1],5,2,8<6[8:1],5,8,1-5[8:1],5,
                    {8}1,7,8,1,2x/7x-5[8:1],,4/7,3-1[8:1],
                    {8},3/4,5,,7,7,5,6,
                    {8}5/3-5[8:1],,3/6,7,8-4[8:1],1,2,,
                    {8}3/5,,4qq8[2:1],4,7,,5,,
                    {8}6pp2[2:1],6,3,,5,,4qq1[2:1],4,
                    {12}8,,,5,,,8,7,6,5/3-6[8:1],,,
                    {8}3/7-2[8:1],,7/1-5[8:1],,1x/8x,,6,6,
                    {8}5>3[8:1],7,8h[4:1],,1,1,7<5[8:1],3,
                    {8}2h[4:1],,4,4,1<7[8:1],2,3h[4:1],,
                    {8}5,5,3>1[8:1],7,8h[4:1],,5,6h[4:1],
                    {8},3,4h[4:1],,2h[4:1],,3>6[2:1],3p6[8:3],
                    {12},,,,,,,,,1,2,3,
                    {8}6/4-2[8:1],,4/8-4[8:1],,1x/8x,,3,3,
                    {8}4<7[8:1],2,1h[4:1],,8,8,1>4[8:1],6,
                    {8}7h[4:1],,5,5,6<1[8:1],4,3h[4:1],,
                    {8}4,4,3,4,1h[4:1]/5,,3,3h[4:1],
                    {8},5,5<8[4:1],,8-4[4:1],,4>1[4:1],,
                    {8}1s5[4:1],,,,6<3[2:1],6q3[8:3],,,
                    {8},,,,1b/8b,,3,2/4-8[8:1],
                    {8},1,2-6[8:1],,2/7-1[8:1],,7/3-5[8:1],,
                    {8}3/6,,6,7/5-1[8:1],,8,7-3[8:1],,
                    {8}7/2-8[8:1],,2/6-4[8:1],,3/6,,3,4/2z6[4:1],
                    {8},7,8-4[8:1],,8>3[4:1],,3<6[4:1],,
                    {8}6,,8,1/7s3[4:1],,2,1-5[8:1],,
                    {4}1<6[4:1],6>7<5[8:5],C1f,,
                    {24},,,,,,1x,2,3,7x,6,5,2x,3,4,8x,7,6,1x,2,3,7x,6,5,
                    {8}4b/8b,,1x-4[8:1],4-2[8:1],1,5,6h[4:1],,
                    {8}2-5[8:1],5-3[8:1],2,6,7h[4:1],,3-6[8:1],6-4[8:1],
                    {8}3,7,8h[4:1],,4-7[8:1],7-5[8:1],4,8,
                    {8}1h[4:1],,3-8[8:1],8-2[8:1],3,5,6h[4:1],,
                    {8}4-7[8:1],7-5[8:1],4,8,1h[4:1],,3-8[8:1],8-2[8:1],
                    {8}3,5,6h[4:1],,1,1,2/8,3/7,
                    {8}4h[4:1]/6,,8-5[8:1],5-7[8:1],8,4,3h[4:1],,
                    {8}7-4[8:1],4-6[8:1],7,3,2h[4:1],,6-3[8:1],3-5[8:1],
                    {8}6,2,1h[4:1],,5-2[8:1],2-4[8:1],5,1,
                    {8}8h[4:1],,6-1[8:1],1-7[8:1],6,2,3h[4:1],,
                    {8}5-2[8:1],2-4[8:1],5,1,8h[4:1],,7,7,
                    {32}1,,,,1,,,,D5,D4,D3,D2,D1,D8,D7,D6,A4,A3,A2,A1,A8,A7,A6,A5,C1f,,,,,,,,
                    {8}1b/8b,,8-5-7[4:1],2,8,4,3,3,
                    {8}7-5-1[4:1],1,7,3,2,2,6-3-5[4:1],8,
                    {8}6,2,1,1,5-3-7[4:1],3,5,1,
                    {8}8,8,6-1-7[4:1],5,6,3,4,4,
                    {8}8-2-6[4:1],2,8,5,4,4,7,8<5[8:1],
                    {8}1,2,3>8[8:1],4,5,6>3[8:1],7,8,
                    {8}1b,,1-4-2[4:1],7,1,5,6,6,
                    {8}2-4-8[4:1],8,2,6,7,7,3-6-4[4:1],1,
                    {8}3,7,8,8,4-6-2[4:1],6,4,8,
                    {8}1,1,3-8-2[4:1],4,3,6,5,5,
                    {8}1-5[8:1],7,1,8,3/7,3/7,2/6,2/6,
                    {8}1/5,1/5,4/8-3[8:1],,8/6-1[8:1],,5/6,,
                    {1}2b/8bpp4>5[4:11],
                    {1},
                    {1},
                    {4}4h[2:3],,,B3,
                    {4},6,6h[2:3],,
                    {4},E7,E6,E5,
                    {4}3h[2:3],,,E3,
                    {4},5,5h[2:1],,
                    {4}4,3/5,2/6,7/1-5[8:1],
                    {8}8b,,7,3,,1/5,7-5[8:1],,
                    {8}7/1-3[8:1],,1/8-4[8:1],,8,,2,6,
                    {8},4/8,2-4[8:1],,2/8-6[8:1],,8/1-5[8:1],,
                    {8}C1f,,7,7,5,5,6,6,
                    {8}3,3,4,4,1,1,3,3,
                    {8}5,5,4/7-3[8:1],,7/2-6[8:1],,2/8,,
                    {8}7,7,5,5,6,6,3,3,
                    {8}4,4,1,1,7-1[8:1],7,3-5[8:1],3,
                    {8}7-3[8:1],7,1,,2,2,2,2,
                    {4}1/4h[4:1],8>3[4:1],3<6[4:1],6,
                    {8}7,7,7,7,5h[4:1]/8,,1<6[4:1],,
                    {8}6>3[4:1],,3,,1,,2/4,2/4,
                    {8}1xh[4:1]/5x-1[8:1],,,A2/E3/A3f/D3/E4/A4/D4,,,8xh[4:1]/4x-8[8:1],,
                    {8},A5/E6/A6f/D6/E7/A7/D7,,,1xh[4:1]/5xh[4:1],,,C1f/B3/A3/E4/B7/A7/E8,
                    {8},,2x/6x,2/6,1x/5x,1/5,8x/4xq6[2:9],4/8q2b[8:35],
                    {1},
                    {1},
                    {1},
                    {1},
                    {1},
                    {1},
                    {8}4/5,,2,4,3,5,4/5,,
                    {8}7,5,6,4,4/5,,2,4,
                    {8}3,5,4/6,,7,5,6,4,
                    {8}3/5,,1,4,3,6,5/7,,
                    {8}8,5,6,3,2/4,,1,8,
                    {8}3,6,4-8[8:1]/5-1[8:1],,4/5,,2b/7b,,
                    {8}4bh[8:1]/5bh[8:1],,6-1-7-4[8:3]b,5,6,4,3,3,
                    {8}2-5-3-8[8:3]b,1,2,8,7,7,6-2-8-5[8:3]b,2,
                    {8}6,4,3,3,2-6-4-1[8:3]b,4,2,8,
                    {8}7,7,6-2-8-4[8:3]b,1,6,4,3,3,
                    {8}2-6-4-8[8:3]b,5,2,8,7,7,1-5b[8:1],1,
                    {8}8-4b[8:1],8,3v6b[8:1],3,7-4b[8:1],7,7/2-5b[8:1],2,
                    {8}2x/7b,,8-5b[8:1],5-7-4[4:1]b,8,4,3b,3,
                    {8}2-5b[8:1],5-3-8[4:1]b,2,8,7b,7,6-2b[8:1],2-8-4[4:1]b,
                    {8}6,4,3b,3,1-4b[8:1],4-2-6[4:1]b,1,6,
                    {8}7b,7,4/8,4/8,3/7,2/6,1b/5b,1/5,
                    {32}4,,3,,2,,1,,8,,7,,6,,5,,2b,3,4,5,6,7,8,1,2,3,4,5,6,7,8,1,
                    {32}2,3,4,5,6,7,8,1,2x-7b[8:1]/6x-3b[8:1],,,,,,,,2x/6x,,,,,,,,1b/5b,,,,,,,,
                    {1}3bpp6>1[2:5]b/7bpp2<5[2:5]b,
                    {1},
                    {1},
                    {8}8>3[8:1],7,6,5<8[8:1],4,3,2>5[8:1],1,
                    {8}8,7>2[8:1],6,5,4<7[8:1],3,2,1>4[8:1],
                    {8}8,7,6,6,5,4,3,3,
                    {8}1b-6[8:1],2,3,4-1[8:1],5,6,7-4[8:1],8,
                    {8}1,2-7[8:1],3,4,5-2[8:1],6,7,8-4[8:1],
                    {8}1,2,3,3,4,5,6,6,
                    {8}3/7,3/7,2/6,2/6,1/5,1/5,2/4,3/5,
                    {8}4/6,5/7,4/8<1[2:1],,C1h[2:1],,,,
                    {8},,7b/8b,3b/4b,2b/1bw5[8:1],6b/5bw1b[8:1],1b,C1f,
                    {1},
                    {1},
                    {1},
            E""";

        // 执行提取
        List<String> validList = extractValidSegments(rawText);

        // 输出结果（含分类）
        System.out.println("===== 提取完成，共 " + validList.size() + " 项 =====");
        for (int i = 0; i < validList.size(); i++) {
            String note = validList.get(i);
            NoteType type = classifyNote(note);
            System.out.println((i + 1) + ". " + note + " -> " + type);
        }

        int[] counts = countNoteTypes(validList);
        
        int[] expected = {774, 39, 136, 65, 49};
        
        System.out.println("\n===== 统计结果 =====");
        System.out.printf("%-8s %6s %6s %6s%n", "类型", "统计值", "真实值", "差值");
        System.out.println("----------------------------");
        NoteType[] types = NoteType.values();
        for (int i = 0; i < types.length; i++) {
            int diff = counts[i] - expected[i];
            System.out.printf("%-8s %6d %6d %+6d%n", types[i], counts[i], expected[i], diff);
        }

        List<String>[] groups = collectByType(validList);
        System.out.println("\n===== 各类型字符组集合 =====");
        for (int i = 0; i < types.length; i++) {
            System.out.println(types[i] + ": " + String.join(", ", groups[i]));
            if (i < types.length - 1) {
                System.out.println("----------------------------");
            }
        }
    }
}