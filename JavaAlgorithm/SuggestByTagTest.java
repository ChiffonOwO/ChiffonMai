/**
 * 测试根据标签推荐乐曲
 * 需要导入的依赖：
 * <dependencies>
        <dependency>
        <groupId>com.fasterxml.jackson.core</groupId>
        <artifactId>jackson-databind</artifactId>
        <version>2.16.1</version>
       </dependency>
    </dependencies>
 */

package com.teen9g;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Duration;
import java.util.*;
import java.util.stream.Collectors;
import java.util.zip.GZIPInputStream;
import java.util.zip.InflaterInputStream;

public class SuggestByTagTest {
    // RA 筛选配置常量
    private static final int MAX_LIMIT = 70; // 最大筛选数量
    private static final int RA_RANGE_LIMIT = 20; // RA 极差上限

    // 难度索引映射（level_index → sheet_difficulty）
    private static final Map<Integer, String> LEVEL_INDEX_MAP = new HashMap<>();
    static {
        LEVEL_INDEX_MAP.put(0, "basic");
        LEVEL_INDEX_MAP.put(1, "advanced");
        LEVEL_INDEX_MAP.put(2, "expert");
        LEVEL_INDEX_MAP.put(3, "master");
        LEVEL_INDEX_MAP.put(4, "remaster");
    }

    // 谱面类型映射（type → sheet_type）
    private static final Map<String, String> TYPE_MAP = new HashMap<>();
    static {
        TYPE_MAP.put("SD", "std");
        TYPE_MAP.put("DX", "dx");
    }

    public static void main(String[] args) {
        // 1.检查并下载 maiTags.json
        String tagFileName = "maiTags.json";
        Path tagFilePath = Paths.get(System.getProperty("user.dir"), tagFileName);
        System.out.println("maiTags.json 路径：" + tagFilePath);

        if (Files.exists(tagFilePath)) {
            if (Files.isRegularFile(tagFilePath)) {
                System.out.println("✅ 当前工作目录下存在文件：" + tagFileName);
                System.out.println("文件完整路径：" + tagFilePath.toAbsolutePath());
            } else {
                System.out.println("⚠️ 存在名为 " + tagFileName + " 的路径，但它不是普通文件（可能是文件夹）");
            }
        } else {
            System.out.println("❌ 当前工作目录下不存在文件：" + tagFileName);
            downloadMaiTagsFile(tagFileName);
        }

        // 2.读取并筛选玩家游玩记录（测试用 userPlayData.json）
        String playDataFileName = "userPlayData3.json";
        Path playDataPath = Paths.get(System.getProperty("user.dir"), playDataFileName);

        if (Files.exists(playDataPath) && Files.isRegularFile(playDataPath)) {
            System.out.println("\n========================================");
            System.out.println("开始筛选 RA 数据...");
            // 筛选 RA 数据（只执行一次）
            List<Record> filteredRecords = filterRaData(playDataPath);
            if (!filteredRecords.isEmpty()) {
                System.out.println("\n========================================");
                System.out.println("开始按分类统计各标签出现次数...");
                // 按分组统计标签出现次数
                countTagsByGroup(filteredRecords, tagFilePath);

                // 3.进行曲目推荐(根据标签倾向推荐，以上分为主)
                System.out.println("\n========================================");
                System.out.println("开始进行曲目推荐...");
                // 执行推荐算法，传递已筛选的数据
                recommendSongs(playDataPath, tagFilePath, filteredRecords);
            }
        } else {
            System.err.println("\n❌ 测试数据文件 " + playDataFileName + " 不存在，请先准备数据文件");
        }
        /*
          单曲Rating计算公式
          单曲Rating = [谱面定数 × 完成度 ×100 × 乘数]，其中[x]为x的整数部分，且当完成度大于100.5%时，按100.5%计算
          完成度，评级，乘数的表格对照如下

            完成度		评级		 乘数
            100.5%		SSS+	0.224
            100.4999%	SSS	    0.222
            100%		SSS	    0.216

            例如，15级谱面完成度100.7890%，单曲Rating = [100.5 * 15 * 0.224] = 337
            14.4级谱面完成度99.7000%，单曲Rating= [99.7 * 14..4 * 0.211] = 302
            已知目标达成率范围固定为100.0%-100.50%，目标Rating范围可能是很多情况，计算出合适的定数范围并给出对应最低达成率。如13.8 100.5000% — 14.3 100.0000%
            需要注意的是，介于100.0%-100.50%之间大都有1分的空隙，
            如对于15级谱面，100.0000% 为 [100 * 15 * 0.216] = 324，而100.3087%为 [100.3087 * 15 * 0.216] = 325
         */
    }

    /**
     * 下载 maiTags.json 文件（原有逻辑）
     */
    private static void downloadMaiTagsFile(String fileName) {
        String url = "https://derrakuma.dxrating.net/functions/v1/combined-tags";

        Map<String, String> headers = new HashMap<>();
        headers.put("apikey", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxidHBubWRmZnVpbWlra3Nydm5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDYwMzMxNzAsImV4cCI6MjAyMTYwOTE3MH0.rrzOisCZGz2gkp-yh61-_HDY7YqL3lTc4XsOPzuAVDU");
        headers.put("authorization", "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxidHBubWRmZnVpbWlra3Nydm5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDYwMzMxNzAsImV4cCI6MjAyMTYwOTE3MH0.rrzOisCZGz2gkp-yh61-_HDY7YqL3lTc4XsOPzuAVDU");
        headers.put("origin", "https://dxrating.net");
        headers.put("referer", "https://dxrating.net/");
        headers.put("x-client-info", "supabase-js-web/2.49.1");
        headers.put("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0");
        headers.put("Accept", "*/*");
        headers.put("Accept-Encoding", "gzip, deflate, br");
        headers.put("Accept-Language", "zh-CN,zh;q=0.9,en-GB;q=0.8,en-US;q=0.7,en;q=0.6");

        HttpClient client = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(30))
                .build();

        HttpRequest.Builder requestBuilder = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(Duration.ofSeconds(30))
                .POST(HttpRequest.BodyPublishers.noBody());

        headers.forEach(requestBuilder::header);
        HttpRequest request = requestBuilder.build();

        try {
            HttpResponse<byte[]> response = client.send(request, HttpResponse.BodyHandlers.ofByteArray());

            System.out.println("状态码: " + response.statusCode());
            System.out.println("响应头: " + response.headers().map());

            String contentEncoding = response.headers().firstValue("Content-Encoding").orElse("");
            String contentType = response.headers().firstValue("Content-Type").orElse("默认 UTF-8");
            System.out.println("响应Content-Encoding: " + contentEncoding);
            System.out.println("响应Content-Type: " + contentType);

            byte[] responseBytes = response.body();
            byte[] uncompressedBytes;
            switch (contentEncoding.toLowerCase()) {
                case "gzip":
                    try (GZIPInputStream gzipIn = new GZIPInputStream(new java.io.ByteArrayInputStream(responseBytes))) {
                        uncompressedBytes = gzipIn.readAllBytes();
                    }
                    break;
                case "br":
                    try (InflaterInputStream brIn = new InflaterInputStream(
                            new java.io.ByteArrayInputStream(responseBytes),
                            new java.util.zip.Inflater(true)
                    )) {
                        uncompressedBytes = brIn.readAllBytes();
                    }
                    break;
                case "deflate":
                    try (InflaterInputStream deflateIn = new InflaterInputStream(new java.io.ByteArrayInputStream(responseBytes))) {
                        uncompressedBytes = deflateIn.readAllBytes();
                    }
                    break;
                default:
                    uncompressedBytes = responseBytes;
            }

            String body = new String(uncompressedBytes, StandardCharsets.UTF_8);
            System.out.println("响应内容（前500字符）: " + (body.length() > 500 ? body.substring(0, 500) : body));

            Files.write(Paths.get(fileName), body.getBytes(StandardCharsets.UTF_8));
            System.out.println("✅ 完整响应已以 UTF-8 编码保存到 " + fileName);

        } catch (Exception e) {
            System.err.println("请求失败: " + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * 筛选 RA 数据核心逻辑（返回筛选后的列表，供标签统计使用）
     */
    private static List<Record> filterRaData(Path playDataPath) {
        List<Record> filteredRecords = new ArrayList<>();
        try {
            // 初始化 Jackson ObjectMapper
            ObjectMapper objectMapper = new ObjectMapper();
            objectMapper.enable(SerializationFeature.INDENT_OUTPUT);

            // 读取并解析玩家游玩记录 JSON
            JsonNode rootNode = objectMapper.readTree(playDataPath.toFile());

            // 提取 records 数组
            JsonNode recordsNode;
            if (rootNode.has("records") && rootNode.get("records").isArray()) {
                recordsNode = rootNode.get("records");
            } else if (rootNode.isArray()) {
                recordsNode = rootNode;
            } else {
                System.err.println("❌ JSON 文件中未找到有效的 records 数组");
                return filteredRecords;
            }

            // 转换为 Record 列表并过滤无效数据
            List<Record> recordList = new ArrayList<>();
            for (JsonNode node : recordsNode) {
                if (node.has("ra") && node.get("ra").isNumber()) {
                    Record record = new Record(
                            node.has("achievements") ? node.get("achievements").asDouble() : 0.0,
                            node.has("ds") ? node.get("ds").asDouble() : 0.0,
                            node.has("dxScore") ? node.get("dxScore").asInt() : 0,
                            node.has("fc") ? node.get("fc").asText() : "",
                            node.has("fs") ? node.get("fs").asText() : "",
                            node.has("level") ? node.get("level").asText() : "",
                            node.has("level_index") ? node.get("level_index").asInt() : 0,
                            node.has("level_label") ? node.get("level_label").asText() : "",
                            node.get("ra").asInt(),
                            node.has("rate") ? node.get("rate").asText() : "",
                            node.has("song_id") ? node.get("song_id").asInt() : 0,
                            node.has("title") ? node.get("title").asText() : "",
                            node.has("type") ? node.get("type").asText() : ""
                    );
                    recordList.add(record);
                }
            }

            if (recordList.isEmpty()) {
                System.err.println("❌ 未找到有效 RA 数据的 records");
                return filteredRecords;
            }

            // 按 RA 降序排序
            List<Record> sortedByRaDesc = recordList.stream()
                    .sorted((r1, r2) -> Integer.compare(r2.getRa(), r1.getRa()))
                    .collect(Collectors.toList());

            // 取前 MAX_LIMIT 个数据
            List<Record> top100Records = sortedByRaDesc.stream()
                    .limit(MAX_LIMIT)
                    .collect(Collectors.toList());

            // 筛选 RA 极差 ≤ 20 的数据
            int maxRa = top100Records.get(0).getRa();
            int minRaThreshold = maxRa - RA_RANGE_LIMIT;

            for (Record record : top100Records) {
                if (record.getRa() >= minRaThreshold) {
                    filteredRecords.add(record);
                } else {
                    break;
                }
            }

            // 输出筛选结果
            System.out.println("✅ RA 筛选结果统计：");
            System.out.println("   最大 RA：" + maxRa);
            System.out.println("   最小 RA：" + (filteredRecords.isEmpty() ? 0 : filteredRecords.get(filteredRecords.size() - 1).getRa()));
            System.out.println("   RA 极差：" + (filteredRecords.isEmpty() ? 0 : maxRa - filteredRecords.get(filteredRecords.size() - 1).getRa()));
            System.out.println("   筛选数量：" + filteredRecords.size());
            System.out.println("----------------------------------------");

            // 打印排名信息
            for (int i = 0; i < filteredRecords.size(); i++) {
                Record r = filteredRecords.get(i);
                System.out.printf(
                        "排名 %d | RA: %d | 标题: %s | 难度: %s | FC: %s%n",
                        i + 1, r.getRa(), r.getTitle(), r.getLevel(), r.getFc()
                );
            }

            // 保存筛选结果到文件
            objectMapper.writeValue(Paths.get("filtered_records.json").toFile(), filteredRecords);
            System.out.println("----------------------------------------");
            System.out.println("✅ 筛选结果已保存到 filtered_records.json");

        } catch (Exception e) {
            System.err.println("❌ 筛选 RA 数据失败：" + e.getMessage());
            e.printStackTrace();
        }
        return filteredRecords;
    }

    /**
     * 按分组统计筛选后谱面中各标签的出现次数（核心修改逻辑）
     */
    private static void countTagsByGroup(List<Record> filteredRecords, Path tagFilePath) {
        try {
            // 1. 读取并解析 maiTags.json
            ObjectMapper objectMapper = new ObjectMapper();
            JsonNode tagRootNode = objectMapper.readTree(tagFilePath.toFile());

            // 第一步：构建 分组ID → 分组名称 的映射（如 1→配置，2→难度，3→评价）
            Map<Integer, String> groupIdToNameMap = new HashMap<>();
            JsonNode tagGroupsNode = tagRootNode.has("tagGroups") && tagRootNode.get("tagGroups").isArray()
                    ? tagRootNode.get("tagGroups")
                    : null;
            if (tagGroupsNode == null) {
                System.err.println("❌ maiTags.json 中未找到有效的 tagGroups 数组");
                return;
            }
            for (JsonNode groupNode : tagGroupsNode) {
                int groupId = groupNode.has("id") ? groupNode.get("id").asInt() : -1;
                if (groupId == -1) continue;
                // 获取分组中文名称（优先 zh-Hans）
                String groupName = "";
                if (groupNode.has("localized_name") && groupNode.get("localized_name").has("zh-Hans")) {
                    groupName = groupNode.get("localized_name").get("zh-Hans").asText().trim();
                }
                // 兼容英文（如果没有中文）
                if (groupName.isEmpty() && groupNode.has("localized_name") && groupNode.get("localized_name").has("en")) {
                    groupName = groupNode.get("localized_name").get("en").asText().trim();
                }
                if (!groupName.isEmpty()) {
                    groupIdToNameMap.put(groupId, groupName);
                }
            }

            // 第二步：构建 标签ID → (标签名称, 分组ID) 的映射
            Map<Integer, TagInfo> tagIdToInfoMap = new HashMap<>();
            JsonNode tagsNode = tagRootNode.has("tags") && tagRootNode.get("tags").isArray()
                    ? tagRootNode.get("tags")
                    : null;
            if (tagsNode == null) {
                System.err.println("❌ maiTags.json 中未找到有效的 tags 数组");
                return;
            }
            for (JsonNode tagNode : tagsNode) {
                int tagId = tagNode.has("id") ? tagNode.get("id").asInt() : -1;
                int groupId = tagNode.has("group_id") ? tagNode.get("group_id").asInt() : -1;
                if (tagId == -1 || groupId == -1) continue;

                // 获取标签中文名称
                String tagName = "";
                if (tagNode.has("localized_name") && tagNode.get("localized_name").has("zh-Hans")) {
                    tagName = tagNode.get("localized_name").get("zh-Hans").asText().trim();
                }
                if (tagName.isEmpty()) continue;

                // 存储标签信息（名称+分组ID）
                tagIdToInfoMap.put(tagId, new TagInfo(tagName, groupId));
            }

            // 第三步：构建 谱面标识 → 标签ID列表 的映射
            Map<String, List<Integer>> songToTagIdsMap = new HashMap<>();
            JsonNode tagSongsNode = tagRootNode.has("tagSongs") && tagRootNode.get("tagSongs").isArray()
                    ? tagRootNode.get("tagSongs")
                    : null;
            if (tagSongsNode == null) {
                System.err.println("❌ maiTags.json 中未找到有效的 tagSongs 数组");
                return;
            }
            for (JsonNode tagSongNode : tagSongsNode) {
                String songId = tagSongNode.has("song_id") ? tagSongNode.get("song_id").asText().trim() : "";
                String sheetType = tagSongNode.has("sheet_type") ? tagSongNode.get("sheet_type").asText().trim() : "";
                String sheetDifficulty = tagSongNode.has("sheet_difficulty") ? tagSongNode.get("sheet_difficulty").asText().trim() : "";
                int tagId = tagSongNode.has("tag_id") ? tagSongNode.get("tag_id").asInt() : -1;

                if (songId.isEmpty() || sheetType.isEmpty() || sheetDifficulty.isEmpty() || tagId == -1) {
                    continue; // 跳过无效数据
                }

                String songKey = songId + "#" + sheetType + "#" + sheetDifficulty;
                if (!songToTagIdsMap.containsKey(songKey)) {
                    songToTagIdsMap.put(songKey, new ArrayList<>());
                }
                songToTagIdsMap.get(songKey).add(tagId);
            }

            // 第四步：遍历筛选后的RA谱面，按分组统计标签出现次数
            // 分组名 → (标签名 → 出现次数)
            Map<String, Map<String, Integer>> groupTagCountMap = new HashMap<>();
            Set<String> processedSongKeys = new HashSet<>(); // 避免重复统计同一谱面

            for (Record record : filteredRecords) {
                String songTitle = record.getTitle().trim();
                String sheetType = TYPE_MAP.getOrDefault(record.getType().trim(), "");
                String sheetDifficulty = LEVEL_INDEX_MAP.getOrDefault(record.getLevel_index(), "");

                if (songTitle.isEmpty() || sheetType.isEmpty() || sheetDifficulty.isEmpty()) {
                    System.out.printf("⚠️ 谱面 %s（类型：%s，难度索引：%d）字段不完整，跳过标签统计%n",
                            songTitle, record.getType(), record.getLevel_index());
                    continue;
                }

                String songKey = songTitle + "#" + sheetType + "#" + sheetDifficulty;
                if (processedSongKeys.contains(songKey)) {
                    continue;
                }
                processedSongKeys.add(songKey);

                // 获取该谱面的所有标签ID
                List<Integer> tagIds = songToTagIdsMap.getOrDefault(songKey, new ArrayList<>());
                for (int tagId : tagIds) {
                    TagInfo tagInfo = tagIdToInfoMap.get(tagId);
                    if (tagInfo == null) continue; // 跳过无信息的标签

                    // 获取分组名称
                    String groupName = groupIdToNameMap.getOrDefault(tagInfo.getGroupId(), "未知分组");
                    // 初始化分组的标签统计Map
                    if (!groupTagCountMap.containsKey(groupName)) {
                        groupTagCountMap.put(groupName, new HashMap<>());
                    }
                    Map<String, Integer> tagCountMap = groupTagCountMap.get(groupName);

                    // 累加标签出现次数
                    String tagName = tagInfo.getTagName();
                    tagCountMap.put(tagName, tagCountMap.getOrDefault(tagName, 0) + 1);
                }
            }

            // 第五步：按要求格式输出统计结果
            System.out.println("✅ 按分组统计标签出现次数（筛选后RA谱面）：");
            System.out.println("----------------------------------------");
            // 遍历每个分组
            for (Map.Entry<String, Map<String, Integer>> groupEntry : groupTagCountMap.entrySet()) {
                String groupName = groupEntry.getKey();
                Map<String, Integer> tagCountMap = groupEntry.getValue();

                // 将该分组下的标签按出现次数降序排序
                List<Map.Entry<String, Integer>> sortedTagEntries = new ArrayList<>(tagCountMap.entrySet());
                sortedTagEntries.sort((e1, e2) -> Integer.compare(e2.getValue(), e1.getValue()));

                // 拼接输出字符串（格式：标签名 - 次数 | 标签名 - 次数）
                StringBuilder tagStrBuilder = new StringBuilder();
                for (int i = 0; i < sortedTagEntries.size(); i++) {
                    Map.Entry<String, Integer> tagEntry = sortedTagEntries.get(i);
                    if (i > 0) {
                        tagStrBuilder.append(" | ");
                    }
                    tagStrBuilder.append(tagEntry.getKey()).append(" - ").append(tagEntry.getValue());
                }

                // 输出分组结果
                System.out.printf("%s：%s%n", groupName, tagStrBuilder);
            }

            // 补充统计信息
            System.out.println("----------------------------------------");
            System.out.printf("参与统计的唯一谱面数：%d%n", processedSongKeys.size());
            // 计算总标签种类数和总出现次数
            int totalTagType = 0;
            int totalTagCount = 0;
            for (Map<String, Integer> tagCountMap : groupTagCountMap.values()) {
                totalTagType += tagCountMap.size();
                totalTagCount += tagCountMap.values().stream().mapToInt(Integer::intValue).sum();
            }
            System.out.printf("总标签种类数：%d%n", totalTagType);
            System.out.printf("所有标签总出现次数：%d%n", totalTagCount);

        } catch (Exception e) {
            System.err.println("❌ 按分组统计标签出现次数失败：" + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * 标签信息实体类（标签名 + 分组ID）
     */
    private static class TagInfo {
        private String tagName;
        private int groupId;

        public TagInfo(String tagName, int groupId) {
            this.tagName = tagName;
            this.groupId = groupId;
        }

        public String getTagName() {
            return tagName;
        }

        public int getGroupId() {
            return groupId;
        }
    }



    /**
     * Record 实体类（对应 records 元数据）
     */
    static class Record {
        private double achievements;
        private double ds;
        private int dxScore;
        private String fc;
        private String fs;
        private String level;
        private int level_index;
        private String level_label;
        private int ra;
        private String rate;
        private int song_id;
        private String title;
        private String type;

        public Record(double achievements, double ds, int dxScore, String fc, String fs,
                      String level, int level_index, String level_label, int ra,
                      String rate, int song_id, String title, String type) {
            this.achievements = achievements;
            this.ds = ds;
            this.dxScore = dxScore;
            this.fc = fc;
            this.fs = fs;
            this.level = level;
            this.level_index = level_index;
            this.level_label = level_label;
            this.ra = ra;
            this.rate = rate;
            this.song_id = song_id;
            this.title = title;
            this.type = type;
        }

        // Getter 方法
        public int getRa() { return ra; }
        public String getTitle() { return title; }
        public String getLevel() { return level; }
        public String getFc() { return fc; }
        public double getAchievements() { return achievements; }
        public double getDs() { return ds; }
        public int getDxScore() { return dxScore; }
        public String getFs() { return fs; }
        public int getLevel_index() { return level_index; }
        public String getLevel_label() { return level_label; }
        public String getRate() { return rate; }
        public int getSong_id() { return song_id; }
        public String getType() { return type; }
    }

    /**
     * 推荐算法实现
     */
    private static void recommendSongs(Path playDataPath, Path tagFilePath, List<Record> filteredRecords) {
        try {
            // 1. 使用已筛选的玩家单曲Rating前70位数据
            System.out.println("(1) 使用已筛选的玩家单曲Rating前70位数据...");
            
            if (filteredRecords.isEmpty()) {
                System.err.println("❌ 没有足够的有效数据进行推荐");
                return;
            }

            // 2. 根据标签的出现频率计算玩家的能力向量（三个向量）
        System.out.println("(2) 根据标签的出现频率计算玩家的能力向量...");
        Map<String, Map<String, Double>> playerAbilityVectors = calculatePlayerAbilityVectors(filteredRecords, tagFilePath);
        
        // 输出三个向量的信息
        System.out.println("\n========================================");
        System.out.println("玩家能力向量分析：");
        System.out.println("========================================");
        System.out.println("配置向量 (group_id=1) 维度: " + playerAbilityVectors.get("config").size());
        System.out.println("难度向量 (group_id=2) 维度: " + playerAbilityVectors.get("difficulty").size());
        System.out.println("评价向量 (group_id=3) 维度: " + playerAbilityVectors.get("evaluation").size());
        System.out.println("========================================");
        System.out.println("能力向量计算完成！");
        System.out.println("========================================");

            // 3. 获取玩家的过往版本中的Best55和当前版本中的Best15
            System.out.println("(3) 获取玩家的Best55和Best15数据...");
            List<Record> allRecords = getAllRecords(playDataPath);
            List<Record> best55 = getBestNRecords(allRecords, 55, false);
            List<Record> best35 = getBestNRecords(best55, 35, false); // 从best55中取前35位作为b35
            List<Record> best15 = getBestNRecords(allRecords, 15, true);
            
            // 输出b55、b35和b15数据用于调试
            System.out.println("\n========================================");
            System.out.println("调试信息 - Best55数据：");
            System.out.println("========================================");
            showRecords(best55, "Best55");
            
            System.out.println("\n========================================");
            System.out.println("调试信息 - Best35数据：");
            System.out.println("========================================");
            showRecords(best35, "Best35");
            
            System.out.println("\n========================================");
            System.out.println("调试信息 - Best15数据：");
            System.out.println("========================================");
            showRecords(best15, "Best15");

            // 4. 获取Best55、Best35和Best15的单曲Rating范围
        System.out.println("(4) 获取Best55、Best35和Best15的单曲Rating范围...");
        RaRange best55Range = getRaRange(best55);
        RaRange best35Range = getRaRange(best35); // 获取b35的Rating范围
        RaRange best15Range = getRaRange(best15);
        
        // 输出三组Rating的范围
        System.out.println("\n========================================");
        System.out.println("Rating范围分析：");
        System.out.println("========================================");
        System.out.printf("Best55 Rating范围: %d — %d%n", best55Range.getMinRa(), best55Range.getMaxRa());
        System.out.printf("Best35 Rating范围: %d — %d%n", best35Range.getMinRa(), best35Range.getMaxRa());
        System.out.printf("Best15 Rating范围: %d — %d%n", best15Range.getMinRa(), best15Range.getMaxRa());
        System.out.println("========================================");

            // 5. 根据Rating范围定位到可供上分的定数范围
            System.out.println("(5) 根据Rating范围定位到可供上分的定数范围...");
            DifficultyRange best55DiffRange = getDifficultyRange(best35Range); // 使用b35的范围计算b55的定数范围
            DifficultyRange best15DiffRange = getDifficultyRange(best15Range);

            // 6. 分别计算Best55和Best15的推荐结果
            System.out.println("(6) 计算谱面考察点向量并进行相似度计算...");
            
            // 6.1 计算Best55推荐结果（isNew=false）
            System.out.println("(6.1) 计算Best55推荐结果...");
            List<RecommendationResult> best55Recommendations = calculateRecommendations(
                    allRecords, tagFilePath, playerAbilityVectors, best55DiffRange, false
            );
            
            // 6.2 计算Best15推荐结果（isNew=true）
            System.out.println("(6.2) 计算Best15推荐结果...");
            List<RecommendationResult> best15Recommendations = calculateRecommendations(
                    allRecords, tagFilePath, playerAbilityVectors, best15DiffRange, true
            );

            // 7. 展现推荐结果
            System.out.println("(7) 展现推荐结果...");
            
            // 7.1 展现Best55推荐结果
            System.out.println("(7.1) 展现Best55推荐结果...");
            showRecommendations(best55Recommendations, "Best55");
            
            // 7.2 展现Best15推荐结果
            System.out.println("(7.2) 展现Best15推荐结果...");
            showRecommendations(best15Recommendations, "Best15");

            // 8. 输出合适的定数范围
            System.out.println("(8) 输出合适的定数范围...");
            showDifficultyRange(best55DiffRange, "Best55");
            showDifficultyRange(best15DiffRange, "Best15");

        } catch (Exception e) {
            System.err.println("❌ 推荐算法执行失败：" + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * 获取所有记录
     */
    private static List<Record> getAllRecords(Path playDataPath) throws Exception {
        ObjectMapper objectMapper = new ObjectMapper();
        JsonNode rootNode = objectMapper.readTree(playDataPath.toFile());

        List<Record> records = new ArrayList<>();
        JsonNode recordsNode;
        if (rootNode.has("records") && rootNode.get("records").isArray()) {
            recordsNode = rootNode.get("records");
        } else if (rootNode.isArray()) {
            recordsNode = rootNode;
        } else {
            return records;
        }

        for (JsonNode node : recordsNode) {
            if (node.has("ra") && node.get("ra").isNumber()) {
                Record record = new Record(
                        node.has("achievements") ? node.get("achievements").asDouble() : 0.0,
                        node.has("ds") ? node.get("ds").asDouble() : 0.0,
                        node.has("dxScore") ? node.get("dxScore").asInt() : 0,
                        node.has("fc") ? node.get("fc").asText() : "",
                        node.has("fs") ? node.get("fs").asText() : "",
                        node.has("level") ? node.get("level").asText() : "",
                        node.has("level_index") ? node.get("level_index").asInt() : 0,
                        node.has("level_label") ? node.get("level_label").asText() : "",
                        node.get("ra").asInt(),
                        node.has("rate") ? node.get("rate").asText() : "",
                        node.has("song_id") ? node.get("song_id").asInt() : 0,
                        node.has("title") ? node.get("title").asText() : "",
                        node.has("type") ? node.get("type").asText() : ""
                );
                records.add(record);
            }
        }
        return records;
    }

    /**
     * 获取前N个记录
     */
    private static List<Record> getBestNRecords(List<Record> records, int n, boolean isNewOnly) {
        try {
            // 读取maimai_music_data.json
            Path musicDataPath = Paths.get(System.getProperty("user.dir"), "maimai_music_data.json");
            ObjectMapper objectMapper = new ObjectMapper();
            JsonNode musicDataArray = objectMapper.readTree(musicDataPath.toFile());
            
            // 构建songId到isNew的映射
            Map<Integer, Boolean> songIdToIsNewMap = new HashMap<>();
            if (musicDataArray.isArray()) {
                for (JsonNode songNode : musicDataArray) {
                    if (songNode.has("id") && songNode.has("basic_info")) {
                        try {
                            int songId = Integer.parseInt(songNode.get("id").asText());
                            JsonNode basicInfoNode = songNode.get("basic_info");
                            boolean isNew = basicInfoNode.has("is_new") && basicInfoNode.get("is_new").asBoolean();
                            songIdToIsNewMap.put(songId, isNew);
                        } catch (NumberFormatException e) {
                            // 跳过非数字ID
                        }
                    }
                }
            }
            
            // 过滤并排序
            return records.stream()
                    .filter(record -> {
                        Boolean isNew = songIdToIsNewMap.get(record.getSong_id());
                        if (!isNewOnly) {
                            // Best55：只包含is_new为false的歌曲
                            return isNew != null && !isNew;
                        } else {
                            // Best15：只包含is_new为true的歌曲
                            return isNew != null && isNew;
                        }
                    })
                    .sorted((r1, r2) -> Integer.compare(r2.getRa(), r1.getRa()))
                    .limit(n)
                    .collect(Collectors.toList());
        } catch (Exception e) {
            System.err.println("❌ 读取音乐数据失败：" + e.getMessage());
            // 出错时返回所有记录的前N个
            return records.stream()
                    .sorted((r1, r2) -> Integer.compare(r2.getRa(), r1.getRa()))
                    .limit(n)
                    .collect(Collectors.toList());
        }
    }

    /**
     * Rating范围
     */
    private static class RaRange {
        private int minRa;
        private int maxRa;

        public RaRange(int minRa, int maxRa) {
            this.minRa = minRa;
            this.maxRa = maxRa;
        }

        public int getMinRa() { return minRa; }
        public int getMaxRa() { return maxRa; }
    }

    /**
     * 获取Rating范围
     */
    private static RaRange getRaRange(List<Record> records) {
        if (records.isEmpty()) {
            return new RaRange(0, 0);
        }
        int minRa = records.stream().mapToInt(Record::getRa).min().orElse(0) + 1;
        int maxRa = records.stream().mapToInt(Record::getRa).max().orElse(0) + 1;
        return new RaRange(minRa, maxRa);
    }

    /**
     * 定数范围
     */
    private static class DifficultyRange {
        private double minDs;
        private double maxDs;
        private int minRa;
        private int maxRa;

        public DifficultyRange(double minDs, double maxDs, int minRa, int maxRa) {
            this.minDs = minDs;
            this.maxDs = maxDs;
            this.minRa = minRa;
            this.maxRa = maxRa;
        }

        public double getMinDs() { return minDs; }
        public double getMaxDs() { return maxDs; }
        public int getMinRa() { return minRa; }
        public int getMaxRa() { return maxRa; }
    }

    /**
     * 根据Rating范围获取定数范围
     */
    private static DifficultyRange getDifficultyRange(RaRange raRange) {
        // 简化计算：基于RA和定数的关系
        // 假设完成度为100.5%，乘数为0.224
        double minDs = raRange.getMinRa() / (100.5 * 0.224);
        double maxDs = raRange.getMaxRa() / (100.0 * 0.216);
        return new DifficultyRange(minDs, maxDs, raRange.getMinRa(), raRange.getMaxRa());
    }

    /**
     * 计算玩家能力向量（按三个tag种类分别计算）
     */
    private static Map<String, Map<String, Double>> calculatePlayerAbilityVectors(List<Record> records, Path tagFilePath) throws Exception {
        // 读取标签数据
        ObjectMapper objectMapper = new ObjectMapper();
        JsonNode tagRootNode = objectMapper.readTree(tagFilePath.toFile());

        // 构建标签映射
        Map<String, List<Integer>> songToTagIdsMap = buildSongToTagIdsMap(tagRootNode);
        Map<Integer, String> tagIdToNameMap = buildTagIdToNameMap(tagRootNode);
        Map<Integer, Integer> tagIdToGroupMap = buildTagIdToGroupMap(tagRootNode);

        // 按group_id统计标签出现次数
        Map<Integer, Map<String, Integer>> groupTagCounts = new HashMap<>();
        Map<Integer, Integer> groupTotalTags = new HashMap<>();
        
        // 初始化三个group
        groupTagCounts.put(1, new HashMap<>()); // 配置
        groupTagCounts.put(2, new HashMap<>()); // 难度
        groupTagCounts.put(3, new HashMap<>()); // 评价
        groupTotalTags.put(1, 0);
        groupTotalTags.put(2, 0);
        groupTotalTags.put(3, 0);

        Set<String> processedSongKeys = new HashSet<>();

        for (Record record : records) {
            String songTitle = record.getTitle().trim();
            String sheetType = TYPE_MAP.getOrDefault(record.getType().trim(), "");
            String sheetDifficulty = LEVEL_INDEX_MAP.getOrDefault(record.getLevel_index(), "");

            if (songTitle.isEmpty() || sheetType.isEmpty() || sheetDifficulty.isEmpty()) {
                continue;
            }

            String songKey = songTitle + "#" + sheetType + "#" + sheetDifficulty;
            if (processedSongKeys.contains(songKey)) {
                continue;
            }
            processedSongKeys.add(songKey);

            // 获取该谱面的所有标签ID
            List<Integer> tagIds = songToTagIdsMap.getOrDefault(songKey, new ArrayList<>());
            for (int tagId : tagIds) {
                String tagName = tagIdToNameMap.getOrDefault(tagId, "");
                Integer groupId = tagIdToGroupMap.get(tagId);
                
                if (!tagName.isEmpty() && groupId != null && (groupId == 1 || groupId == 2 || groupId == 3)) {
                    // 统计到对应的group
                    Map<String, Integer> tagCounts = groupTagCounts.get(groupId);
                    tagCounts.put(tagName, tagCounts.getOrDefault(tagName, 0) + 1);
                    groupTotalTags.put(groupId, groupTotalTags.get(groupId) + 1);
                }
            }
        }

        // 计算三个向量
        Map<String, Map<String, Double>> abilityVectors = new HashMap<>();
        
        // 配置向量 (group_id=1)
        Map<String, Double> configVector = new HashMap<>();
        Map<String, Integer> configTagCounts = groupTagCounts.get(1);
        int configTotal = groupTotalTags.get(1);
        if (configTotal > 0) {
            for (Map.Entry<String, Integer> entry : configTagCounts.entrySet()) {
                double frequency = (double) entry.getValue() / configTotal;
                configVector.put(entry.getKey(), frequency);
            }
        }
        abilityVectors.put("config", configVector);
        
        // 难度向量 (group_id=2)
        Map<String, Double> difficultyVector = new HashMap<>();
        Map<String, Integer> difficultyTagCounts = groupTagCounts.get(2);
        int difficultyTotal = groupTotalTags.get(2);
        if (difficultyTotal > 0) {
            for (Map.Entry<String, Integer> entry : difficultyTagCounts.entrySet()) {
                double frequency = (double) entry.getValue() / difficultyTotal;
                difficultyVector.put(entry.getKey(), frequency);
            }
        }
        abilityVectors.put("difficulty", difficultyVector);
        
        // 评价向量 (group_id=3)
        Map<String, Double> evaluationVector = new HashMap<>();
        Map<String, Integer> evaluationTagCounts = groupTagCounts.get(3);
        int evaluationTotal = groupTotalTags.get(3);
        if (evaluationTotal > 0) {
            for (Map.Entry<String, Integer> entry : evaluationTagCounts.entrySet()) {
                double frequency = (double) entry.getValue() / evaluationTotal;
                evaluationVector.put(entry.getKey(), frequency);
            }
        }
        abilityVectors.put("evaluation", evaluationVector);
        
        return abilityVectors;
    }

    /**
     * 构建谱面到标签ID的映射
     */
    private static Map<String, List<Integer>> buildSongToTagIdsMap(JsonNode tagRootNode) {
        Map<String, List<Integer>> map = new HashMap<>();
        JsonNode tagSongsNode = tagRootNode.has("tagSongs") && tagRootNode.get("tagSongs").isArray()
                ? tagRootNode.get("tagSongs")
                : null;

        if (tagSongsNode != null) {
            for (JsonNode tagSongNode : tagSongsNode) {
                String songId = tagSongNode.has("song_id") ? tagSongNode.get("song_id").asText().trim() : "";
                String sheetType = tagSongNode.has("sheet_type") ? tagSongNode.get("sheet_type").asText().trim() : "";
                String sheetDifficulty = tagSongNode.has("sheet_difficulty") ? tagSongNode.get("sheet_difficulty").asText().trim() : "";
                int tagId = tagSongNode.has("tag_id") ? tagSongNode.get("tag_id").asInt() : -1;

                if (!songId.isEmpty() && !sheetType.isEmpty() && !sheetDifficulty.isEmpty() && tagId != -1) {
                    String songKey = songId + "#" + sheetType + "#" + sheetDifficulty;
                    map.computeIfAbsent(songKey, k -> new ArrayList<>()).add(tagId);
                }
            }
        }
        return map;
    }

    /**
     * 构建标签ID到名称的映射
     */
    private static Map<Integer, String> buildTagIdToNameMap(JsonNode tagRootNode) {
        Map<Integer, String> map = new HashMap<>();
        JsonNode tagsNode = tagRootNode.has("tags") && tagRootNode.get("tags").isArray()
                ? tagRootNode.get("tags")
                : null;

        if (tagsNode != null) {
            for (JsonNode tagNode : tagsNode) {
                int tagId = tagNode.has("id") ? tagNode.get("id").asInt() : -1;
                if (tagId == -1) continue;

                String tagName = "";
                if (tagNode.has("localized_name") && tagNode.get("localized_name").has("zh-Hans")) {
                    tagName = tagNode.get("localized_name").get("zh-Hans").asText().trim();
                }
                if (!tagName.isEmpty()) {
                    map.put(tagId, tagName);
                }
            }
        }
        return map;
    }
    
    /**
     * 构建标签ID到group_id的映射
     */
    private static Map<Integer, Integer> buildTagIdToGroupMap(JsonNode tagRootNode) {
        Map<Integer, Integer> map = new HashMap<>();
        JsonNode tagsNode = tagRootNode.has("tags") && tagRootNode.get("tags").isArray()
                ? tagRootNode.get("tags")
                : null;

        if (tagsNode != null) {
            for (JsonNode tagNode : tagsNode) {
                int tagId = tagNode.has("id") ? tagNode.get("id").asInt() : -1;
                int groupId = tagNode.has("group_id") ? tagNode.get("group_id").asInt() : -1;
                
                if (tagId != -1 && groupId != -1) {
                    map.put(tagId, groupId);
                }
            }
        }
        return map;
    }

    /**
     * 推荐结果
     */
    private static class RecommendationResult {
        private String songTitle;
        private String level;
        private double ds;
        private double similarity;
        private double minAchievement;

        public RecommendationResult(String songTitle, String level, double ds, double similarity, double minAchievement) {
            this.songTitle = songTitle;
            this.level = level;
            this.ds = ds;
            this.similarity = similarity;
            this.minAchievement = minAchievement;
        }

        public String getSongTitle() { return songTitle; }
        public String getLevel() { return level; }
        public double getDs() { return ds; }
        public double getSimilarity() { return similarity; }
        public double getMinAchievement() { return minAchievement; }
    }

    /**
     * 计算推荐结果
     */
    private static List<RecommendationResult> calculateRecommendations(
            List<Record> records, Path tagFilePath, Map<String, Map<String, Double>> playerVectors,
            DifficultyRange diffRange, boolean isNew) throws Exception {

        List<RecommendationResult> results = new ArrayList<>();
        Set<String> processedSongs = new HashSet<>();
        
        // 读取maimai_music_data.json获取is_new属性
        Path musicDataPath = Paths.get(System.getProperty("user.dir"), "maimai_music_data.json");
        ObjectMapper objectMapper = new ObjectMapper();
        JsonNode musicDataArray = objectMapper.readTree(musicDataPath.toFile());
        
        // 构建songId到isNew的映射
        Map<Integer, Boolean> songIdToIsNewMap = new HashMap<>();
        if (musicDataArray.isArray()) {
            for (JsonNode songNode : musicDataArray) {
                if (songNode.has("id") && songNode.has("basic_info")) {
                    try {
                        int songId = Integer.parseInt(songNode.get("id").asText());
                        JsonNode basicInfoNode = songNode.get("basic_info");
                        boolean songIsNew = basicInfoNode.has("is_new") && basicInfoNode.get("is_new").asBoolean();
                        songIdToIsNewMap.put(songId, songIsNew);
                    } catch (NumberFormatException e) {
                        // 跳过非数字ID
                    }
                }
            }
        }

        for (Record record : records) {
            // 检查歌曲是否属于目标曲库
            Boolean songIsNew = songIdToIsNewMap.get(record.getSong_id());
            if (songIsNew == null || songIsNew != isNew) {
                continue;
            }
            
            // 检查达成率是否已经>=100.5%
            if (record.getAchievements() >= 100.5) {
                continue;
            }
            
            String songTitle = record.getTitle();
            String level = record.getLevel();
            double ds = record.getDs();
            String songKey = songTitle + "#" + level;

            if (processedSongs.contains(songKey)) {
                continue;
            }
            processedSongs.add(songKey);

            // 检查定数是否在推荐范围内
                if (ds >= diffRange.getMinDs() && ds <= diffRange.getMaxDs()) {
                    // 计算谱面考察点向量（三个向量）
                    Map<String, Map<String, Double>> songVectors = calculateSongVectors(record, tagFilePath);
                    // 计算综合相似度
                    double similarity = calculate综合Similarity(playerVectors, songVectors);
                    // 计算能落入rating区间的最低达成率
                    // 使用最低Rating作为目标，确保能落入区间
                    double minAchievement = calculateMinAchievement(ds, diffRange.getMinRa());
                    
                    // 过滤掉达成率小于100%的推荐结果
                    if (minAchievement >= 1.0) {
                        results.add(new RecommendationResult(songTitle, level, ds, similarity, minAchievement));
                    }
                }
        }

        // 按相似度降序排序
        results.sort((r1, r2) -> Double.compare(r2.getSimilarity(), r1.getSimilarity()));
        return results;
    }

    /**
     * 计算谱面向量
     */
    private static Map<String, Double> calculateSongVector(Record record, Path tagFilePath) throws Exception {
        // 简化实现：基于标签出现次数
        Map<String, Double> vector = new HashMap<>();
        // 实际应用中应该基于谱面的具体标签计算
        return vector;
    }

    /**
     * 计算向量相似度（余弦相似度）
     */
    private static double calculateSimilarity(Map<String, Double> vec1, Map<String, Double> vec2) {
        if (vec1.isEmpty() || vec2.isEmpty()) {
            return 0.0;
        }

        // 计算点积
        double dotProduct = 0.0;
        for (String key : vec1.keySet()) {
            if (vec2.containsKey(key)) {
                dotProduct += vec1.get(key) * vec2.get(key);
            }
        }

        // 计算向量长度
        double length1 = Math.sqrt(vec1.values().stream().mapToDouble(v -> v * v).sum());
        double length2 = Math.sqrt(vec2.values().stream().mapToDouble(v -> v * v).sum());

        if (length1 == 0 || length2 == 0) {
            return 0.0;
        }

        return dotProduct / (length1 * length2);
    }
    
    /**
     * 计算谱面向量（按三个tag种类分别计算）
     */
    private static Map<String, Map<String, Double>> calculateSongVectors(Record record, Path tagFilePath) throws Exception {
        // 读取标签数据
        ObjectMapper objectMapper = new ObjectMapper();
        JsonNode tagRootNode = objectMapper.readTree(tagFilePath.toFile());

        // 构建标签映射
        Map<String, List<Integer>> songToTagIdsMap = buildSongToTagIdsMap(tagRootNode);
        Map<Integer, String> tagIdToNameMap = buildTagIdToNameMap(tagRootNode);
        Map<Integer, Integer> tagIdToGroupMap = buildTagIdToGroupMap(tagRootNode);

        // 按group_id统计标签出现次数
        Map<Integer, Map<String, Integer>> groupTagCounts = new HashMap<>();
        Map<Integer, Integer> groupTotalTags = new HashMap<>();
        
        // 初始化三个group
        groupTagCounts.put(1, new HashMap<>()); // 配置
        groupTagCounts.put(2, new HashMap<>()); // 难度
        groupTagCounts.put(3, new HashMap<>()); // 评价
        groupTotalTags.put(1, 0);
        groupTotalTags.put(2, 0);
        groupTotalTags.put(3, 0);

        // 获取当前谱面的标签
        String songTitle = record.getTitle().trim();
        String sheetType = TYPE_MAP.getOrDefault(record.getType().trim(), "");
        String sheetDifficulty = LEVEL_INDEX_MAP.getOrDefault(record.getLevel_index(), "");

        if (!songTitle.isEmpty() && !sheetType.isEmpty() && !sheetDifficulty.isEmpty()) {
            String songKey = songTitle + "#" + sheetType + "#" + sheetDifficulty;
            List<Integer> tagIds = songToTagIdsMap.getOrDefault(songKey, new ArrayList<>());
            
            for (int tagId : tagIds) {
                String tagName = tagIdToNameMap.getOrDefault(tagId, "");
                Integer groupId = tagIdToGroupMap.get(tagId);
                
                if (!tagName.isEmpty() && groupId != null && (groupId == 1 || groupId == 2 || groupId == 3)) {
                    // 统计到对应的group
                    Map<String, Integer> tagCounts = groupTagCounts.get(groupId);
                    tagCounts.put(tagName, tagCounts.getOrDefault(tagName, 0) + 1);
                    groupTotalTags.put(groupId, groupTotalTags.get(groupId) + 1);
                }
            }
        }

        // 计算三个向量
        Map<String, Map<String, Double>> songVectors = new HashMap<>();
        
        // 配置向量 (group_id=1)
        Map<String, Double> configVector = new HashMap<>();
        Map<String, Integer> configTagCounts = groupTagCounts.get(1);
        int configTotal = groupTotalTags.get(1);
        if (configTotal > 0) {
            for (Map.Entry<String, Integer> entry : configTagCounts.entrySet()) {
                double frequency = (double) entry.getValue() / configTotal;
                configVector.put(entry.getKey(), frequency);
            }
        }
        songVectors.put("config", configVector);
        
        // 难度向量 (group_id=2)
        Map<String, Double> difficultyVector = new HashMap<>();
        Map<String, Integer> difficultyTagCounts = groupTagCounts.get(2);
        int difficultyTotal = groupTotalTags.get(2);
        if (difficultyTotal > 0) {
            for (Map.Entry<String, Integer> entry : difficultyTagCounts.entrySet()) {
                double frequency = (double) entry.getValue() / difficultyTotal;
                difficultyVector.put(entry.getKey(), frequency);
            }
        }
        songVectors.put("difficulty", difficultyVector);
        
        // 评价向量 (group_id=3)
        Map<String, Double> evaluationVector = new HashMap<>();
        Map<String, Integer> evaluationTagCounts = groupTagCounts.get(3);
        int evaluationTotal = groupTotalTags.get(3);
        if (evaluationTotal > 0) {
            for (Map.Entry<String, Integer> entry : evaluationTagCounts.entrySet()) {
                double frequency = (double) entry.getValue() / evaluationTotal;
                evaluationVector.put(entry.getKey(), frequency);
            }
        }
        songVectors.put("evaluation", evaluationVector);
        
        return songVectors;
    }
    
    /**
     * 计算三个向量的综合相似度
     */
    private static double calculate综合Similarity(Map<String, Map<String, Double>> playerVectors, Map<String, Map<String, Double>> songVectors) {
        // 计算每个向量的相似度
        double configSimilarity = calculateSimilarity(playerVectors.get("config"), songVectors.get("config"));
        double difficultySimilarity = calculateSimilarity(playerVectors.get("difficulty"), songVectors.get("difficulty"));
        double evaluationSimilarity = calculateSimilarity(playerVectors.get("evaluation"), songVectors.get("evaluation"));
        
        // 加权平均（可以根据需要调整权重）
        double weightConfig = 0.5;
        double weightDifficulty = 0.3;
        double weightEvaluation = 0.2;
        
        return configSimilarity * weightConfig + difficultySimilarity * weightDifficulty + evaluationSimilarity * weightEvaluation;
    }

    /**
     * 计算能落入rating区间的最低达成率
     */
    private static double calculateMinAchievement(double ds, int targetRa) {
        // 计算能达到目标RA的最低达成率
        // 假设乘数为0.216（SSS评级）
        double achievement = targetRa / (ds * 100 * 0.216);
        // 限制最高达成率为100.5%
        return Math.min(achievement, 1.005);
    }

    /**
     * 展示推荐结果
     */
    private static void showRecommendations(List<RecommendationResult> recommendations, String title) {
        System.out.println("\n========================================");
        System.out.println(title + "推荐结果（按相似度降序）：");
        System.out.println("========================================");
        System.out.printf("%-30s %-10s %-10s %-15s %-20s%n", "曲目", "难度", "定数", "相似度", "最低达成率");
        System.out.println("------------------------------------------------------------------------------------");

        int rank = 1;
        for (RecommendationResult result : recommendations) {
            System.out.printf("%-40s %-8s %-8.2f %-10.4f %-12.4f%%%n",
                    result.getSongTitle(),
                    result.getLevel(),
                    result.getDs(),
                    result.getSimilarity(),
                    result.getMinAchievement() * 100
            );
            if (rank >= 20) break; // 只显示前20个推荐结果
            rank++;
        }

        System.out.println("------------------------------------------------------------------------------------");
        System.out.printf("%s推荐完成！总计：%d 条推荐\n", title, recommendations.size());
    }

    /**
     * 展示推荐结果（兼容旧方法）
     */
    private static void showRecommendations(List<RecommendationResult> recommendations) {
        showRecommendations(recommendations, "");
    }

    /**
     * 展示记录数据
     */
    private static void showRecords(List<Record> records, String title) {
        if (records.isEmpty()) {
            System.out.println("❌ 没有数据");
            return;
        }
        
        System.out.printf("%-5s %-25s %-10s %-10s %-10s%n", "排名", "曲目", "难度", "定数", "RA值");
        System.out.println("------------------------------------------------------------------------------------");
        
        int rank = 1;
        for (Record record : records) {
            System.out.printf("%-5d %-25s %-10s %-10.2f %-10d%n",
                    rank,
                    record.getTitle(),
                    record.getLevel(),
                    record.getDs(),
                    record.getRa()
            );
            if (rank >= 20) break; // 只显示前20条
            rank++;
        }
        
        System.out.println("------------------------------------------------------------------------------------");
        System.out.printf("总计：%d 条记录\n", records.size());
    }

    /**
     * 展示定数范围
     */
    private static void showDifficultyRange(DifficultyRange diffRange, String title) {
        System.out.println("\n========================================");
        System.out.println(title + "合适的定数范围：");
        System.out.println("========================================");
        
        // 计算最高定数的100.5000% — 最低定数的100.0000%
        double minDs = diffRange.getMinDs();
        double maxDs = diffRange.getMaxDs();
        
        // 计算100.5000%达成率对应的RA
        double raAt100_5 = maxDs * 100.5 * 100 * 0.224;
        // 计算100.0000%达成率对应的RA
        double raAt100_0 = minDs * 100.0 * 100 * 0.216;
        
        System.out.printf("%.1f 100.5000%% — %.1f 100.0000%%%n", minDs, maxDs);
        System.out.println("========================================");
    }

    /**
     * 展示定数范围（兼容旧方法）
     */
    private static void showDifficultyRange(DifficultyRange best55Range, DifficultyRange best15Range) {
        showDifficultyRange(best55Range, "Best55 ");
        showDifficultyRange(best15Range, "Best15 ");
    }
}