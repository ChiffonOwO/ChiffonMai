import requests

# 1. 配置请求基础信息
url = "https://derrakuma.dxrating.net/functions/v1/combined-tags"

# 2. 核心请求头（完全照搬浏览器的配置，尤其是认证和跨域相关）
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxidHBubWRmZnVpbWlra3Nydm5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDYwMzMxNzAsImV4cCI6MjAyMTYwOTE3MH0.rrzOisCZGz2gkp-yh61-_HDY7YqL3lTc4XsOPzuAVDU",
    "authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxidHBubWRmZnVpbWlra3Nydm5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDYwMzMxNzAsImV4cCI6MjAyMTYwOTE3MH0.rrzOisCZGz2gkp-yh61-_HDY7YqL3lTc4XsOPzuAVDU",
    "origin": "https://dxrating.net",
    "referer": "https://dxrating.net/",
    "x-client-info": "supabase-js-web/2.49.1",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0",
    "Accept": "*/*",
    "Accept-Encoding": "gzip, deflate, br",
    "Accept-Language": "zh-CN,zh;q=0.9,en-GB;q=0.8,en-US;q=0.7,en;q=0.6"
}

try:
    # 3. 发送 POST 请求（无请求体，data 传空即可）
    response = requests.post(
        url=url,
        headers=headers,
        data=b"",  # 空请求体，对应 content-length: 0
        timeout=30,  # 设置超时时间，避免卡壳
        verify=True  # 验证 SSL 证书，生产环境建议开启
    )

    # 4. 打印响应结果
    print("状态码:", response.status_code)
    print("响应头:", dict(response.headers))
    print("响应内容（前500字符）:", response.text[:500])  # 内容较长，先打印前500字符

    # 如果需要保存完整响应内容到文件
    with open("response.json", "w", encoding="utf-8") as f:
        f.write(response.text)
    print("完整响应已保存到 response.json 文件")

except requests.exceptions.RequestException as e:
    # 异常处理：捕获网络错误、超时等问题
    print("请求失败:", str(e))