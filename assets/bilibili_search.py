"""
B站视频搜索工具 — 按标题搜索视频并获取播放量。

用法:
    python bilibili_search.py "maimai定数变化表"
    python bilibili_search.py "关键词" --page 2 --order pubdate
    python bilibili_search.py "关键词" --json   # 输出完整JSON

依赖: pip install requests
"""

import hashlib
import json
import time
import sys
import argparse
import uuid
import random
from urllib.parse import urlencode

import requests


# ============================================================
# WBI 签名相关
# ============================================================

MIXIN_KEY_ENC_TAB = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
    27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
    37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
    22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
]


def get_mixin_key(raw_key: str) -> str:
    """从原始密钥生成 32 位 mixin_key"""
    return "".join(raw_key[i] for i in MIXIN_KEY_ENC_TAB)[:32]


def sign_wbi(params: dict, img_key: str, sub_key: str) -> dict:
    """对请求参数进行 WBI 签名"""
    mixin_key = get_mixin_key(img_key + sub_key)
    params["wts"] = int(time.time())
    params = dict(sorted(params.items()))
    query = urlencode(params)
    w_rid = hashlib.md5((query + mixin_key).encode()).hexdigest()
    params["w_rid"] = w_rid
    return params


# ============================================================
# 全局持久 Session（关键：复用，避免每次生成新 buvid3）
# ============================================================

class BiliClient:
    """
    持久化的 B站 API 客户端。

    解决"有时能搜到有时搜不到"的问题：
    1. Session 全局复用 —— buvid3 不变，B站不会把它当新设备
    2. WBI 密钥缓存 —— 避免每次都调 /nav，降低风控概率
    3. 预热首页 —— 先访问 bilibili.com 建立正常的浏览轨迹
    4. 重试机制 —— 遇到风控自动重试
    """

    def __init__(self):
        self._session: requests.Session | None = None
        self._img_key: str = ""
        self._sub_key: str = ""
        self._wbi_expire_at: float = 0  # WBI 密钥过期时间戳

    # ------------------------------------------------------------------
    # Session（懒加载，全局复用）
    # ------------------------------------------------------------------

    @property
    def session(self) -> requests.Session:
        if self._session is None:
            self._session = self._warm_up()
        return self._session

    def _warm_up(self) -> requests.Session:
        """
        预热 Session：先访问 B站首页，建立正常的浏览轨迹，
        拿到真实的 buvid3 + buvid4 + _uuid 等 Cookie。
        """
        sess = requests.Session()
        sess.headers.update({
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/131.0.0.0 Safari/537.36"
            ),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Accept-Encoding": "gzip, deflate",
        })

        print("[init] 正在预热 Session（访问 bilibili.com）...", file=sys.stderr)

        try:
            # 先访问首页，拿完整 Cookie
            resp = sess.get(
                "https://www.bilibili.com",
                timeout=15,
                allow_redirects=True,
            )
            print(f"[init] 首页响应: {resp.status_code}", file=sys.stderr)
        except Exception as e:
            print(f"[init] 首页访问异常: {e}", file=sys.stderr)

        # 检查拿到了哪些关键 Cookie
        cookie_names = [c.name for c in sess.cookies]
        print(f"[init] 获取到的 Cookie: {cookie_names}", file=sys.stderr)

        # 如果没拿到 buvid3，手动设置一个
        if "buvid3" not in cookie_names:
            fake_buvid3 = str(uuid.uuid4()).upper()[:8] + "-XXXX-XXXX-XXXX-" + str(uuid.uuid4()).upper()[:12] + str(random.randint(10000, 99999)) + "infoc"
            sess.cookies.set("buvid3", fake_buvid3, domain=".bilibili.com")
            print(f"[init] 未获取到 buvid3，已手动设置", file=sys.stderr)

        # 也确保有 buvid4 和 _uuid
        if "buvid4" not in cookie_names:
            fake_buvid4 = str(uuid.uuid4()).upper() + "-" + str(random.randint(10000, 99999)) + "-" + time.strftime("%m%d%H%M%S") + "-" + str(random.randint(100000, 999999))
            sess.cookies.set("buvid4", fake_buvid4, domain=".bilibili.com")

        if "_uuid" not in cookie_names:
            fake_uuid_val = str(uuid.uuid4()).upper()[:8] + "-" + str(uuid.uuid4()).upper()[:4] + "10-" + str(uuid.uuid4()).upper()[:4] + "-" + str(uuid.uuid4()).upper()[:4] + str(uuid.uuid4()).upper()[:8] + str(random.randint(10000, 99999)) + "infoc"
            sess.cookies.set("_uuid", fake_uuid_val, domain=".bilibili.com")

        # 更新 Referer（后续 API 请求用）
        sess.headers["Referer"] = "https://www.bilibili.com"

        print("[init] Session 预热完成", file=sys.stderr)
        return sess

    # ------------------------------------------------------------------
    # WBI 密钥（缓存 + 自动刷新）
    # ------------------------------------------------------------------

    def _wbi_keys_expired(self) -> bool:
        return time.time() > self._wbi_expire_at

    def _ensure_wbi_keys(self):
        """确保 WBI 密钥有效，过期则重新获取"""
        if self._img_key and self._sub_key and not self._wbi_keys_expired():
            return

        print("[wbi] 获取 WBI 密钥...", file=sys.stderr)
        resp = self.session.get(
            "https://api.bilibili.com/x/web-interface/nav",
            headers={
                "Accept": "application/json, text/plain, */*",
                "Referer": "https://www.bilibili.com",
            },
            timeout=15,
        )
        print(f"[wbi] /nav 响应: HTTP {resp.status_code}, 前200字符: {resp.text[:200]}", file=sys.stderr)

        if resp.status_code != 200:
            raise RuntimeError(f"/nav 返回非200: HTTP {resp.status_code}")

        try:
            data = resp.json()
        except json.JSONDecodeError:
            raise RuntimeError(f"/nav 返回的不是 JSON (HTTP {resp.status_code}): {resp.text[:300]}")

        # /nav 即使未登录也返回 wbi_img，code 可能是 -101
        wbi = (data.get("data") or {}).get("wbi_img")
        if not wbi:
            raise RuntimeError(f"/nav 未返回 wbi_img: code={data.get('code')}, msg={data.get('message', '')}")
        self._img_key = wbi["img_url"].split("/")[-1].split(".")[0]
        self._sub_key = wbi["sub_url"].split("/")[-1].split(".")[0]
        # 缓存 4 小时（B站大约每天轮换，保守设短一些）
        self._wbi_expire_at = time.time() + 4 * 3600
        print(f"[wbi] 密钥已更新 (有效期至 {time.strftime('%H:%M:%S', time.localtime(self._wbi_expire_at))})", file=sys.stderr)

    # ------------------------------------------------------------------
    # 搜索
    # ------------------------------------------------------------------

    def search_videos(
        self,
        keyword: str,
        page: int = 1,
        order: str = "click",
        duration: int = 0,
        tids: int = 0,
        author: str = "",
        max_retries: int = 3,
    ) -> list[dict]:
        """
        搜索B站视频。

        参数:
            keyword:     搜索关键词
            page:        页码
            order:       排序 (click/pubdate/dm/stow/totalrank)
            duration:    时长 (0=全部, 1=<10min, 2=10-30min, 3=30-60min, 4=>60min)
            tids:        分区ID (0=全部)
            author:      限定UP主名字（模糊匹配，留空则不限制）
            max_retries: 最大重试次数

        返回:
            视频列表
        """
        self._ensure_wbi_keys()

        params = {
            "search_type": "video",
            "keyword": keyword,
            "page": page,
            "order": order,
            "duration": duration,
            "tids": tids,
        }

        signed = sign_wbi(params, self._img_key, self._sub_key)
        url = f"https://api.bilibili.com/x/web-interface/wbi/search/type?{urlencode(signed)}"

        for attempt in range(max_retries):
            print(f"[search] 第 {attempt + 1}/{max_retries} 次尝试: keyword={keyword}, page={page}", file=sys.stderr)

            try:
                resp = self.session.get(
                    url,
                    headers={
                        "Accept": "application/json, text/plain, */*",
                        "Referer": "https://www.bilibili.com",
                    },
                    timeout=15,
                )
            except requests.RequestException as e:
                print(f"[search] 请求异常: {e}", file=sys.stderr)
                if attempt < max_retries - 1:
                    wait = 2 ** attempt + random.uniform(0, 1)
                    print(f"[search] 等待 {wait:.1f}s 后重试...", file=sys.stderr)
                    time.sleep(wait)
                    continue
                raise

            print(f"[search] 响应: HTTP {resp.status_code}", file=sys.stderr)

            try:
                data = resp.json()
            except json.JSONDecodeError:
                print(f"[search] 响应不是 JSON (前200字符): {resp.text[:200]}", file=sys.stderr)
                if attempt < max_retries - 1:
                    wait = 2 ** attempt + random.uniform(0, 2)
                    print(f"[search] 等待 {wait:.1f}s 后重试...", file=sys.stderr)
                    time.sleep(wait)
                    continue
                raise RuntimeError(f"B站返回了非JSON内容 (HTTP {resp.status_code})")

            code = data.get("code", -1)
            message = data.get("message", "")

            # 成功
            if code == 0:
                break

            # -412: 风控拦截，重试
            # -799: 频率限制，等待后重试
            # -352: 风控失败
            if code in (-412, -799, -352) and attempt < max_retries - 1:
                wait = (2 ** attempt) * 2 + random.uniform(1, 3)
                print(f"[search] 被风控 (code={code}, msg={message})，等待 {wait:.1f}s 后重试...", file=sys.stderr)
                # 重新预热 Session（可能旧的被标记了）
                if code == -412:
                    print("[search] 重置 Session...", file=sys.stderr)
                    self._session = self._warm_up()
                    self._wbi_expire_at = 0  # 强制刷新 WBI
                    self._ensure_wbi_keys()
                    # 重新签名（因为 wts 变了）
                    signed = sign_wbi(params, self._img_key, self._sub_key)
                    url = f"https://api.bilibili.com/x/web-interface/wbi/search/type?{urlencode(signed)}"
                time.sleep(wait)
                continue

            # 不可恢复的错误
            raise RuntimeError(f"API 错误: code={code}, message={message}")

        if data["code"] != 0:
            raise RuntimeError(f"API 错误: code={data['code']}, message={data.get('message', '')}")

        # 解析结果
        results = data.get("data", {}).get("result", [])
        videos = []
        for item in results:
            if item.get("type") != "video":
                continue
            title = item.get("title", "").replace('<em class="keyword">', "").replace("</em>", "")
            item_author = item.get("author", "")
            if author and author not in item_author:
                continue
            videos.append({
                "title": title,
                "bvid": item.get("bvid", ""),
                "aid": item.get("aid", 0),
                "play": item.get("play", 0),
                "video_review": item.get("video_review", 0),
                "favorites": item.get("favorites", 0),
                "author": item_author,
                "mid": item.get("mid", 0),
                "duration": item.get("duration", ""),
                "pubdate": item.get("pubdate", 0),
                "description": item.get("description", ""),
                "tag": item.get("tag", ""),
                "pic": item.get("pic", ""),
            })

        return videos


# ============================================================
# 全局单例
# ============================================================

_client: BiliClient | None = None


def get_client() -> BiliClient:
    global _client
    if _client is None:
        _client = BiliClient()
    return _client


def search_videos(**kwargs) -> list[dict]:
    """便捷函数，内部复用全局 Session"""
    return get_client().search_videos(**kwargs)


# ============================================================
# CLI
# ============================================================

ORDER_MAP = {
    "click": "click",
    "pubdate": "pubdate",
    "dm": "dm",
    "stow": "stow",
    "totalrank": "totalrank",
}


def main():
    parser = argparse.ArgumentParser(
        description="B站视频搜索工具 — 按标题搜索视频并获取播放量",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python bilibili_search.py "maimai定数变化表"
  python bilibili_search.py "maimai定数变化表" --author DJNaugthy
  python bilibili_search.py "maimai定数变化表" --author 風又ねリ
  python bilibili_search.py "关键词" --page 2
  python bilibili_search.py "关键词" --order pubdate
  python bilibili_search.py "关键词" --duration 1   # 只看<10分钟的
  python bilibili_search.py "关键词" --json          # 输出原始JSON
        """,
    )
    parser.add_argument("keyword", help="搜索关键词")
    parser.add_argument("--page", type=int, default=1, help="页码 (默认: 1)")
    parser.add_argument(
        "--order", default="click",
        choices=list(ORDER_MAP.keys()),
        help="排序方式 (默认: click=播放量)",
    )
    parser.add_argument(
        "--duration", type=int, default=0,
        choices=[0, 1, 2, 3, 4],
        help="时长筛选: 0=全部 1=<10min 2=10-30min 3=30-60min 4=>60min",
    )
    parser.add_argument("--tids", type=int, default=0, help="分区ID (默认: 0=全部)")
    parser.add_argument("--author", default="", help="限定UP主名字，模糊匹配 (如: --author DJNaugthy)")
    parser.add_argument("--json", action="store_true", help="输出原始JSON格式")

    args = parser.parse_args()

    try:
        videos = search_videos(
            keyword=args.keyword,
            page=args.page,
            order=args.order,
            duration=args.duration,
            tids=args.tids,
            author=args.author,
        )
    except Exception as e:
        print(f"搜索失败: {e}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(json.dumps(videos, ensure_ascii=False, indent=2))
        return

    if not videos:
        print("未找到相关视频。")
        return

    print(f"\n搜索「{args.keyword}」共 {len(videos)} 条结果 (第{args.page}页)\n")
    print(f"{'序号':<4} {'标题':<40} {'播放量':<12} {'UP主':<16} {'时长':<8}")
    print("-" * 85)
    for i, v in enumerate(videos, 1):
        play_str = _format_number(v["play"])
        print(f"{i:<4} {v['title'][:38]:<40} {play_str:<12} {v['author'][:14]:<16} {v['duration']:<8}")


def _format_number(n: int) -> str:
    if n >= 10000:
        return f"{n / 10000:.1f}万"
    return str(n)


if __name__ == "__main__":
    main()
