# 本机控制服务与 flclashctl

Rust 动态库只负责应用进程内的独立 UDS 传输；Dart LocalControlService 负责逐命令认证、串行调度和凭据轮换。业务调用注入 CapabilityExecutor，配置事务和 Core 生命周期继续由原权威所有者处理。

默认关闭。设置中首次启用时，只有 Keychain 确认记录不存在才生成 32 随机字节的 base64url 密码。读取失败不会覆盖记录。CLI 使用独立 .control.credentials Keychain service，与 AI 凭据隔离；密码只在设置明确查看或复制时呈现。

## 使用

应用包内工具路径为 FlClash Usage.app/Contents/Resources/control/flclashctl，不会自动改动 PATH。

~~~sh
'/Applications/FlClash Usage.app/Contents/Resources/control/flclashctl' status
'/Applications/FlClash Usage.app/Contents/Resources/control/flclashctl' capabilities
'/Applications/FlClash Usage.app/Contents/Resources/control/flclashctl' start
'/Applications/FlClash Usage.app/Contents/Resources/control/flclashctl' invoke operation_query '{"operationId":"返回的操作ID"}'
'/Applications/FlClash Usage.app/Contents/Resources/control/flclashctl' --password-stdin --idempotency-key task-001 invoke <command> <JSON>
'/Applications/FlClash Usage.app/Contents/Resources/control/flclashctl' --password-fd 3 invoke <command> <JSON>
~~~

默认从终端无回显读取密码。自动化可选标准输入或独立文件描述符；不支持密码参数和密码环境变量。--help、--version 不连接应用。应用未运行时不会启动另一份 GUI。命令不会自动重试；断线或超时后先查询持久操作结果。修改流程由统一能力层返回预览和操作 ID，再用绑定摘要与版本的 capability_confirm 确认。

退出码：0 为完成、已接受或待人工结果；2 为服务拒绝、冲突或执行失败；1 为参数、输入或传输失败。

## 组合与关闭

LocalControlService 接受安全存储、传输、执行回调、onEnabledChanged、onCredentialRotated 和 drainCapabilities。启用偏好只持久化布尔值，默认 false；主应用在初始化及恢复结束后才启动服务。drainCapabilities 必须等待已接受但仍在后台持久化的真实事务；查询超时不会释放该所有权。轮换暂停进入执行边界，拒绝旧排队请求，排空后保存密码、更新代际，并使旧审批失效。保存或排空失败保留旧密码。

每次启动或停用后重启都会生成新的正 53 位随机凭据代际，保持跨 JSON 精确；启动和轮换必须等待 onCredentialRotated 成功后才接受命令。回调失败会关闭服务，旧代际的待确认审批不会复活，已完成操作仍可查询。

真正退出先等待 close()，再进入现有集中退出与 Core 关闭流程；窗口隐藏不关闭服务。关闭有 30 秒排空上限，超限只关闭入口和传输，由既有事务恢复机制处理未完成写入。服务不会启动、杀死或重建 Core。

## 传输边界

- 固定私有目录 /private/tmp/flclashctl-<uid>，0700；socket、发现文件与实例锁 0600。
- 端点与文件拒绝符号链接、所有者或权限不符；发现文件采用无跟随打开，拒绝非普通文件和硬链接，读取上限 4096 字节。
- 实例锁防并发；残留清理要求旧 PID 已退出；退出只删除自身 inode/instance ID 的端点。
- macOS 使用 getpeereid 验证服务端和客户端的当前用户。
- 4 字节 little-endian 长度加 UTF-8 JSON，每帧上限 1 MiB；8 客户端、16 排队。
- 整帧读取上限 5 秒，native/Dart 排队上限 10 秒，查询返回等待 10 秒，native 回复等待 35 秒；超过等待不重做业务。
- 认证失败最多 8 次/5 秒，单调时钟计时；每条命令都重新认证，包括只读目录和结果查询。
- 不记录请求、密码、密码摘要或原始异常。

该传输隔离其他用户，不承诺隔离 root 或已攻陷的同用户进程。macOS 为当前交付平台；其他应用平台明确禁用入口，不回退到明文存储或 TCP。

## 打包与检查

Xcode build phase 调用 /bin/sh services/control/scripts/package_macos.sh；脚本按 ARCHS 构建 arm64/x86_64，合并 CLI 和 dylib，放入 Resources/control 并按应用签名 identity 签名、验证。脚本不包含凭据，测试不用真实 Keychain 或用户配置。

~~~sh
cargo fmt --manifest-path services/control/Cargo.toml -- --check
cargo test --manifest-path services/control/Cargo.toml
flutter test --no-pub test/control --reporter expanded
~~~

原生测试需要 macOS 创建 UDS 的权限，仅使用测试临时目录。测试覆盖帧上限/截断/总读取时限、peer、目录与端点权限、实例锁、8 客户端、活进程残留不清理、替换端点不误删和 CLI 参数不反射密码；Flutter 覆盖首次/重启、Keychain 缺失与失败区别、每命令认证、轮换与真实写入排空、队列/限流、取消编辑和宽窄布局。真实 Keychain 锁定、跨用户进程及系统退出恢复仍需平台交互验收。
