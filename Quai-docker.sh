#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Quai.sh"

# 确保脚本以 root 权限运行
if [ "$(id -u)" -ne "0" ]; then
  echo "请以 root 用户或使用 sudo 运行此脚本"
  exit 1
fi

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "新建了一个电报群，方便大家交流：t.me/Sdohua"
        echo "================================================================"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1) 部署节点"
        echo "2) 查看日志"
        echo "3) 部署 Stratum Proxy"
        echo "4) 启动矿工"
        echo "5) 查看挖矿日志"
        echo "6) 退出"

        read -p "请输入选项: " choice

        case $choice in
            1)
                deploy_node
                ;;
            2)
                view_logs
                ;;
            3)
                deploy_stratum_proxy
                ;;
            4)
                start_miner
                ;;
            5)
                view_mining_logs
                ;;
            6)
                echo "退出脚本..."
                exit 0
                ;;
            *)
                echo "无效选项，请重试。"
                ;;
        esac
    done
}

# 检查 Go 是否安装
function check_go() {
    if ! command -v go &> /dev/null || ! go version | grep -q "go1.23"; then
        echo "Go 1.23 未安装，正在下载并安装最新版本..."
        wget -c https://golang.org/dl/go1.23.2.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local
        echo "export PATH=\$PATH:/usr/local/go/bin" | sudo tee -a /etc/profile
        source /etc/profile
        echo "Go 安装完成！"
    else
        echo "Go 已安装，版本如下："
        go version
    fi
}

# 检查 CUDA 是否安装
function check_cuda() {
    if ! dpkg -l | grep -q "cuda-12-6"; then
        echo "CUDA 12.6 未安装，正在安装..."
        # 这里可以添加安装 CUDA 的命令
        echo "请手动安装 CUDA 12.6，或确保已安装。"
    else
        echo "CUDA 12.6 已安装。"
    fi
}

# 部署节点函数
function deploy_node() {
    # 安装必要的依赖
    echo "正在安装必要的依赖..."
    sudo apt update
    sudo apt install -y git make g++ screen 

    # 创建目录并切换到该目录
    mkdir -p /data/ && cd /data/

    # 检查 Go 是否安装
    if ! command -v go &> /dev/null; then
        echo "Go 未安装，正在下载并安装最新版本..."

        # 下载并安装最新版本的 Go
        wget -q https://golang.org/dl/go1.23.2.linux-amd64.tar.gz -O go.tar.gz
        sudo tar -C /usr/local -xzf go.tar.gz
        rm go.tar.gz

        # 更新 PATH
        echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
        source ~/.bashrc

        echo "Go 安装完成！"
    else
        echo "Go 已安装，版本如下："
    fi

    # 最后检查 Go 版本
    go version

    # 克隆 Git 仓库
    echo "正在克隆 Git 仓库..."
    git clone https://github.com/dominant-strategies/go-quai

    # 切换到 go-quai 目录
    cd go-quai

    # 切换到指定版本
    git checkout v0.38.0

    # 构建项目
    make go-quai

    # 提示用户输入地址
    read -p '请输入 Quai 地址: ' quai_address
    read -p '请输入 Qi 地址: ' qi_address

    # 启动或附加到名为 "node" 的 screen 会话
    screen -dmS node bash -c "./build/bin/go-quai start --node.slices '[0 0]' \
    --node.genesis-nonce 6224362036655375007 \
    --node.quai-coinbases '$quai_address' \
    --node.qi-coinbases '$qi_address' \
    --node.miner-preference '0.5'; exec bash"

    echo "Quai节点已在 screen 会话 'node' 中启动。"
    echo "你可以使用 'screen -r node' 来查看日志。"

    # 等待用户按任意键以返回主菜单
    read -p "按任意键返回主菜单..."
}

# 查看日志函数
function view_logs() {
    echo "正在查看节点日志..."
    tail -f /data/go-quai/nodelogs/global.log
}

# 部署 Stratum Proxy 函数
function deploy_stratum_proxy() {
    echo "正在部署 Stratum Proxy..."
    cd /data/
    git clone https://github.com/dominant-strategies/go-quai-stratum
    cd go-quai-stratum

    # 切换到指定版本
    git checkout v0.16.0

    # 复制配置文件
    cp config/config.example.json config/config.json

    # 切换到 go-quai-stratum 目录
    cd /data/go-quai-stratum

    # 构建 Stratum Proxy
    make go-quai-stratum

    # 在 screen 中运行 Stratum Proxy
    screen -dmS stratum bash -c "./build/bin/go-quai-stratum --region=cyprus --zone=cyprus1 --stratum=3333; exec bash"

    echo "Stratum Proxy 已在 screen 会话 'stratum' 中启动。"
    echo "你可以使用 'screen -r stratum' 来查看日志。"

    # 等待用户按任意键以返回主菜单
    read -p "按任意键返回主菜单..."
}

# 启动矿工函数
function start_miner() {
    # 更新包管理器并安装 NVIDIA 驱动
    echo "正在更新包管理器并安装 NVIDIA 驱动..."
    sudo apt update
    sudo apt install nvidia-driver-560 -y

    # 验证是否安装成功
    echo "验证 NVIDIA 驱动安装..."
    nvidia-smi

    check_cuda

    # 提示用户输入节点 IP
    read -p '请输入节点所在 IP 地址: ' node_ip

    # 下载并安装矿工
    echo "正在下载矿工部署脚本..."
    wget https://raw.githubusercontent.com/dominant-strategies/quai-gpu-miner/refs/heads/main/deploy_miner.sh

    # 修改权限并执行
    sudo chmod +x deploy_miner.sh
    sudo ./deploy_miner.sh

    # 下载并设置矿工可执行权限
    wget -P /usr/local/bin/ https://github.com/dominant-strategies/quai-gpu-miner/releases/download/v0.2.0/quai-gpu-miner
    chmod +x /usr/local/bin/quai-gpu-miner

    # 使用 screen 运行矿工
    echo "正在启动矿工..."

    # 使用 screen 后台运行矿工程序，并将日志重定向到 /var/log/miner.log
    screen -dmS miner bash -c "quai-gpu-miner -U -P stratum://$node_ip:3333 2>&1 | tee /var/log/miner.log"

    echo "矿工已成功在 screen 会话 'miner' 中启动！"
    echo "你可以使用 'screen -r miner' 来查看日志。"

    # 等待用户按任意键以返回主菜单
    read -p "按任意键返回主菜单..."
}

# 查看挖矿日志函数
function view_mining_logs() {
    echo "正在查看挖矿日志..."
    grep Accepted /var/log/miner.log
}

# 启动主菜单
main_menu
