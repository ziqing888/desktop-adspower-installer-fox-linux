#!/bin/bash

# 定义文本格式
BOLD=\$(tput bold)
NORMAL=\$(tput sgr0)
SUCCESS_COLOR='\033[1;32m'
ERROR_COLOR='\033[1;31m'
INFO_COLOR='\033[1;36m'
MENU_COLOR='\033[1;34m'

# 自定义状态显示函数
show_message() {
    local message="\$1"
    local status="\$2"
    case \$status in
        "error")
            echo -e "\${ERROR_COLOR}\${BOLD}❌ 错误: \${message}\${NORMAL}"
            ;;
        "info")
            echo -e "\${INFO_COLOR}\${BOLD}ℹ️ 信息: \${message}\${NORMAL}"
            ;;
        "success")
            echo -e "\${SUCCESS_COLOR}\${BOLD}✅ 成功: \${message}\${NORMAL}"
            ;;
        *)
            echo -e "\${message}"
            ;;
    esac
}

# 提示输入用户名和密码
while true; do
    read -p "请输入远程桌面的用户名: " USER
    if [[ "\$USER" == "root" ]]; then
        show_message "'root' 不能作为用户名。请选择一个不同的用户名。" "error"
    elif [[ "\$USER" =~ [^a-zA-Z0-9] ]]; then
        show_message "用户名包含禁止的字符。只能使用字母和数字字符。" "error"
    else
        break
    fi
done

while true; do
    read -sp "请输入 \$USER 的密码: " PASSWORD
    echo
    if [[ "\$PASSWORD" =~ [^a-zA-Z0-9] ]]; then
        show_message "密码包含禁止的字符。只能使用字母和数字字符。" "error"
    else
        break
    fi
done

# 更新并安装所需的软件包
show_message "正在更新软件包列表..." "info"
sudo apt update

show_message "安装 curl 和 gdebi 以处理 .deb 文件..." "info"
sudo apt install -y curl gdebi-core

# 下载软件包
show_message "正在下载远程桌面工具包..." "info"
curl -O https://example.com/remote-desktop-tool.deb

# 使用 gdebi 安装软件包
show_message "使用 gdebi 安装远程桌面工具..." "info"
sudo gdebi -n remote-desktop-tool.deb

# 安装 XFCE 和 XRDP
show_message "安装 XFCE 桌面以降低资源使用量..." "info"
sudo apt install -y xfce4 xfce4-goodies xubuntu-desktop

show_message "安装 XRDP 以实现远程桌面连接..." "info"
sudo apt install -y xrdp

show_message "正在添加用户 \$USER 并设置指定的密码..." "info"
sudo useradd -m -s /bin/bash \$USER
echo "\$USER:\$PASSWORD" | sudo chpasswd

show_message "将 \$USER 添加到 sudo 组..." "info"
sudo usermod -aG sudo \$USER

# 配置 XRDP 使用 XFCE
show_message "配置 XRDP 使用 XFCE 桌面..." "info"
echo "xfce4-session" | sudo tee /home/\$USER/.xsession

show_message "配置 XRDP 默认使用较低的分辨率..." "info"
sudo sed -i 's/^#xserverbpp=24/xserverbpp=16/' /etc/xrdp/xrdp.ini
show_message "XRDP 配置已更新为使用较低的颜色深度。" "success"

show_message "将分辨率限制为最大 (1280x720)..." "info"
sudo sed -i '/\[xrdp1\]/a max_bpp=16\nxres=1280\nyres=720' /etc/xrdp/xrdp.ini
show_message "XRDP 配置已更新为使用较低的分辨率 (1280x720)。" "success"

show_message "正在重启 XRDP 服务..." "info"
sudo systemctl restart xrdp

show_message "设置 XRDP 服务开机自启..." "info"
sudo systemctl enable xrdp

# 确保桌面目录存在
DESKTOP_DIR="/home/\$USER/Desktop"
if [ ! -d "\$DESKTOP_DIR" ]; then
    show_message "未找到桌面目录。正在为 \$USER 创建桌面目录..." "info"
    sudo mkdir -p "\$DESKTOP_DIR"
    sudo chown \$USER:\$USER "\$DESKTOP_DIR"
fi

# 为远程桌面工具创建桌面快捷方式
DESKTOP_FILE="\$DESKTOP_DIR/RemoteDesktopTool.desktop"
show_message "正在为远程桌面工具创建桌面快捷方式..." "info"

sudo tee \$DESKTOP_FILE > /dev/null <<EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Remote Desktop Tool
Comment=启动远程桌面工具
Exec=/opt/RemoteDesktopTool/RemoteDesktopTool
Icon=/opt/RemoteDesktopTool/resources/icon.png
Terminal=false
StartupNotify=true
Categories=Utility;Application;
EOL

# 设置桌面文件的权限
sudo chmod +x \$DESKTOP_FILE
sudo chown \$USER:\$USER \$DESKTOP_FILE

# 获取服务器 IP 地址
IP_ADDR=\$(hostname -I | awk '{print \$1}')

# 最终提示信息
show_message "安装完成。已安装 XFCE 桌面、XRDP、远程桌面工具以及桌面快捷方式。" "success"
show_message "现在可以通过以下信息进行远程桌面连接:" "info"
show_message "IP 地址: \$IP_ADDR" "info"
show_message "用户名: \$USER" "info"
show_message "密码: \$PASSWORD" "info"

# 重启系统
show_message "正在重启系统以应用所有更改..." "info"
sudo reboot
