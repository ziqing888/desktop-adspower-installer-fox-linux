#!/bin/bash

# 定义颜色代码
INFO='\033[0;36m'  # 青色
WARNING='\033[0;33m' # 黄色
ERROR='\033[0;31m' # 红色
SUCCESS='\033[0;32m' # 绿色
NC='\033[0m' # 无颜色

# 提示输入用户名和密码
while true; do
    read -p "请输入远程桌面的用户名: " USER
    if [[ "$USER" == "root" ]]; then
        echo -e "${ERROR}错误: 'root' 不能作为用户名。请使用其他用户名。${NC}"
    elif [[ "$USER" =~ [^a-zA-Z0-9] ]]; then
        echo -e "${ERROR}错误: 用户名包含非法字符。仅允许字母和数字。${NC}"
    else
        break
    fi
done

while true; do
    read -sp "请输入 $USER 的密码: " PASSWORD
    echo
    if [[ "$PASSWORD" =~ [^a-zA-Z0-9] ]]; then
        echo -e "${ERROR}错误: 密码包含非法字符。仅允许字母和数字。${NC}"
    else
        break
    fi
done

# 更新并安装所需的软件包
echo -e "${INFO}正在更新软件包列表...${NC}"
sudo apt update

echo -e "${INFO}正在安装 curl 和 gdebi 以处理 .deb 文件...${NC}"
sudo apt install -y curl gdebi-core

# 下载 AdsPower .deb 软件包
echo -e "${INFO}正在下载 AdsPower 软件包...${NC}"
curl -O https://version.adspower.net/software/linux-x64-global/AdsPower-Global-5.9.14-x64.deb

# 使用 gdebi 安装 AdsPower
echo -e "${INFO}使用 gdebi 安装 AdsPower...${NC}"
sudo gdebi -n AdsPower-Global-5.9.14-x64.deb

# 安装 XFCE 和 XRDP
echo -e "${INFO}安装 XFCE 轻量桌面环境...${NC}"
sudo apt install -y xfce4 xfce4-goodies xubuntu-desktop

echo -e "${INFO}安装 XRDP 远程桌面服务...${NC}"
sudo apt install -y xrdp

echo -e "${INFO}正在添加用户 $USER 并设置密码...${NC}"
sudo useradd -m -s /bin/bash $USER
echo "$USER:$PASSWORD" | sudo chpasswd

echo -e "${INFO}将 $USER 添加到 sudo 组...${NC}"
sudo usermod -aG sudo $USER

# 配置 XRDP 使用 XFCE
echo -e "${INFO}配置 XRDP 使用 XFCE 桌面...${NC}"
echo "xfce4-session" | sudo tee /home/$USER/.xsession

echo -e "${INFO}将 XRDP 默认颜色深度调整为较低...${NC}"
sudo sed -i 's/^#xserverbpp=24/xserverbpp=16/' /etc/xrdp/xrdp.ini
echo -e "${SUCCESS}XRDP 配置已更新为使用较低的颜色深度。${NC}"

echo -e "${INFO}将分辨率限制为最大 1280x720...${NC}"
sudo sed -i '/\[xrdp1\]/a max_bpp=16\nxres=1280\nyres=720' /etc/xrdp/xrdp.ini
echo -e "${SUCCESS}XRDP 配置已更新为较低分辨率（1280x720）。${NC}"

echo -e "${INFO}正在重启 XRDP 服务...${NC}"
sudo systemctl restart xrdp

echo -e "${INFO}设置 XRDP 开机自启...${NC}"
sudo systemctl enable xrdp

# 确保桌面目录存在
DESKTOP_DIR="/home/$USER/Desktop"
if [ ! -d "$DESKTOP_DIR" ]; then
    echo -e "${INFO}桌面目录不存在。正在为 $USER 创建桌面目录...${NC}"
    sudo mkdir -p "$DESKTOP_DIR"
    sudo chown $USER:$USER "$DESKTOP_DIR"
fi

# 创建 AdsPower 的桌面快捷方式
DESKTOP_FILE="$DESKTOP_DIR/AdsPower.desktop"
echo -e "${INFO}正在创建 AdsPower 的桌面快捷方式...${NC}"

sudo tee $DESKTOP_FILE > /dev/null <<EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=AdsPower
Comment=启动 AdsPower
Exec=/opt/AdsPower/AdsPower
Icon=/opt/AdsPower/resources/app/static/img/icon.png
Terminal=false
StartupNotify=true
Categories=Utility;Application;
EOL

# 设置桌面文件的权限
sudo chmod +x $DESKTOP_FILE
sudo chown $USER:$USER $DESKTOP_FILE

# 获取服务器 IP 地址
IP_ADDR=$(hostname -I | awk '{print $1}')

# 最终提示信息
echo -e "${SUCCESS}安装完成。已安装 XFCE 桌面、XRDP、AdsPower 及桌面快捷方式。${NC}"
echo -e "${INFO}您现在可以通过以下信息进行远程桌面连接:${NC}"
echo -e "${INFO}IP 地址: ${SUCCESS}$IP_ADDR${NC}"
echo -e "${INFO}用户名: ${SUCCESS}$USER${NC}"
echo -e "${INFO}密码: ${SUCCESS}$PASSWORD${NC}"

# 重启系统
echo -e "${INFO}正在重启系统以应用所有更改...${NC}"
sudo reboot
