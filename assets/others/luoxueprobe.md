//updateluoxuescorepage.dart
import 'package:flutter/material.dart';
import 'lxnssyncwebview.dart';
import '../../tools/updatescorepagefun.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';

class UpdateScorePage extends StatefulWidget {
  const UpdateScorePage({super.key});

  @override
  State<StatefulWidget> createState() => _UpdateScorePageState();
}

class _UpdateScorePageState extends State<UpdateScorePage> {
  bool _switchValue = false;
  final SingboxClient singbox = SingboxClient();

  Future<void> exit() async {
    ServiceState state = await singbox.getServiceState();
    if (state == ServiceState.starting || state == ServiceState.started) {
      singbox.disconnect();
    }
    singbox.dispose();
  }

  Future<void> init() async {
    await singbox.initialize();
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更新成绩')),
      body: Center(
        child: Column(
          children: [
            Text('打开下面的开关，打开网页，根据网页提示操作，开关打开期间可能无法正常访问其他网页'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('打开代理'),
                Switch(
                  value: _switchValue,
                  onChanged: (value) async {
                    // String link =
                    //     "vmess://ew0KICAidiI6ICIyIiwNCiAgInBzIjogIjEiLA0KICAiYWRkIjogInByb3h5Lm1haW1haS5seG5zLm5ldCIsDQogICJwb3J0IjogIjgwODAiLA0KICAiaWQiOiAiZGNjM2UzZmYtNjlmNC00NDk0LWI1NDgtMTc0ZWY1ODQ5OWE5IiwNCiAgImFpZCI6ICIwIiwNCiAgInNjeSI6ICJhdXRvIiwNCiAgIm5ldCI6ICJ0Y3AiLA0KICAidHlwZSI6ICJub25lIiwNCiAgInRscyI6ICIiLA0KICAiYWxwbiI6ICIiLA0KICAiaW5zZWN1cmUiOiAiMCINCn0=";
                    // String link = await rootBundle.loadString(
                    //   'res/maimaiproxy.json',
                    // );
                    // print(link);
                    if (value) {
                      // if (!await singbox.requestVPNPermission()) return;
                      await connect(client: singbox);
                    } else {
                      await singbox.disconnect();
                      await singbox.dispose();
                    }
                    if (!mounted) return;
                    setState(() {
                      _switchValue = value;
                    });
                  },
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LxnsSyncWebView(),
                      ),
                    ),
                    child: Text('打开落雪成绩更新网页'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

//updateluoxuescorepagefun.dart
import 'dart:developer';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';
import 'package:flutter/services.dart';

Future<void> connect({required SingboxClient client}) async {
  try {
    if (!await client.requestVPNPermission()) return;
    final config = await rootBundle.loadString('res/maimaiproxy_copy.json');
    // final config = await rootBundle.loadString('res/maimai-prober-proxy.yaml');
    try {
      await client.checkConfig(config);
    } catch (e) {
      log('$e', name: 'updatescorepagefun.dart', level: 1000);
      return;
    }
    await client.connect(
      SessionOptions(
        config: config,
        networkMode: NetworkMode.vpn,
        systemProxyEnabled: true,
        // perAppProxy: PerAppProxyOptions(
        //   mode: PerAppProxyMode.include,
        //   packages: [
        //     'com.k4641321.chusearchsong_flutter',
        //     'com.tencent.mm',
        //     'com.android.chromium',
        //   ],
        // ),
        notification: NotificationConfig(
          title: 'MaimaiProxy',
          showTrafficStats: true,
          showStopButton: false,
        ),
      ),
    );
  } catch (e) {
    log('$e', name: 'updatescorepagefun.dart', level: 1000);
  }
}

//luoxueproxy_copy.json
{
  "log": {
    "level": "info"
  },
  "dns": {},
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "address": [
        "172.18.0.1/30"
      ],
      "platform": {
        "http_proxy": {
          "enabled": true,
          "server": "proxy.maimai.lxns.net",
          "server_port": 8080,
          "bypass_domain": [],
          "match_domain": [
            "wahlap.com"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "http",
      "tag": "maimai DX 查分器代理",
      "server": "proxy.maimai.lxns.net",
      "server_port": 8080
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "domain_suffix": [
          "wahlap.com"
        ],
        "outbound": "maimai DX 查分器代理"
      },
      {
        "ip_cidr": [
          "0.0.0.0/0",
          "::/0"
        ],
        "outbound": "direct-out"
      }
    ]
  }
}

请你新建在"系统"类中新建功能"同步成绩到落雪"，并请将上述代码复刻到本项目中