package main

import (
    "github.com/sagernet/sing-box/common/x"
    // 引入基础协议支持
    _ "github.com/sagernet/sing-box/inbound/vless"
    _ "github.com/sagernet/sing-box/transport/tcp"
    _ "github.com/sagernet/sing-box/transport/internet/http"
)

func main() {
    // 调用官方的核心运行逻辑
    x.Run()
}