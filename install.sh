#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}loi：${plain} hay chay quyen root！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Phiên bản hệ thống không được phát hiện！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}loi khong xac dinh: ${arch}${plain}"
fi

echo "kien truc nhan: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "Phần mềm này không hỗ trợ hệ thống 32 bit (x86), vui lòng sử dụng hệ thống 64 bit (x86_64)"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng hệ thống CentOS 7 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng hệ thống Ubuntu 16 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 trở lên！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}Vì lý do bảo mật, mật khẩu cổng và tài khoản phải được thay đổi sau khi cài đặt/cập nhật${plain}"
    read -p "Bạn muốn tiếp tục?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Vui lòng đặt tên tài khoản của bạn:" config_account
        echo -e "${yellow}Tên tài khoản của bạn sẽ được đặt thành:${config_account}${plain}"
        read -p "Vui lòng đặt mật khẩu tài khoản của bạn:" config_password
        echo -e "${yellow}Mật khẩu tài khoản của bạn sẽ được đặt thành:${config_password}${plain}"
        read -p "Vui lòng đặt cổng truy cập bảng điều khiển:" config_port
        echo -e "${yellow}Cổng truy cập bảng điều khiển của bạn sẽ được đặt thành:${config_port}${plain}"
        echo -e "${yellow}Xác nhận cài đặt, cài đặt${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}Mật khẩu tài khoản được đặt${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}Cài đặt cổng bảng điều khiển đã hoàn tất${plain}"
    else
        echo -e "${red}Đã hủy, tất cả các mục cài đặt là cài đặt mặc định, vui lòng sửa đổi kịp thời${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không thể phát hiện phiên bản x-ui, phiên bản này có thể vượt quá giới hạn của API Github, vui lòng thử lại sau hoặc chỉ định thủ công phiên bản x-ui sẽ cài đặt${plain}"
            exit 1
        fi
        echo -e "Đã phát hiện phiên bản mới nhất của x-ui：${last_version}，bắt đầu cài đặt"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/04gly/04gly_VPN/releases/download/pn1/x-ui-linux-amd64.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống x-ui không thành công, vui lòng đảm bảo rằng máy chủ của bạn có thể tải xuống các tệp từ Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/04gly/04gly_VPN/releases/download/pn1/x-ui-linux-amd64.tar.gz"
        echo -e "Bắt đầu cài đặt x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống x-ui v$1 không thành công, vui lòng đảm bảo rằng phiên bản này tồn tại${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/04gly/04gly_VPN/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "Nếu là bản cài đặt mới, cổng web mặc định là ${green}54321${plain}，Tên người dùng và mật khẩu mặc định là ${green}admin${plain}"
    #echo -e "Vui lòng đảm bảo rằng cổng này không bị chiếm bởi các chương trình khác，${yellow}Và đảm bảo rằng cổng 54321 được mở${plain}"
    #    echo -e "Nếu bạn muốn sửa đổi 54321 thành các cổng khác, hãy nhập lệnh x-ui để sửa đổi, đồng thời đảm bảo rằng cổng bạn sửa đổi cũng được phép"
    #echo -e ""
    #echo -e "Nếu cập nhật bảng điều khiển, hãy truy cập bảng điều khiển như bạn đã làm trước đây"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} Quá trình cài đặt hoàn tất và bảng điều khiển được kích hoạt，"
    echo -e ""
    echo -e "x-ui Cách sử dụng tập lệnh quản lý: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Hiển thị menu quản trị (nhiều tính năng hơn)"
    echo -e "x-ui start        - Bắt đầu bảng điều khiển x-ui"
    echo -e "x-ui stop         - dừng bảng điều khiển x-ui"
    echo -e "x-ui restart      - Khởi động lại bảng điều khiển x-ui"
    echo -e "x-ui status       - Xem trạng thái x-ui"
    echo -e "x-ui enable       - Đặt x-ui tự khởi động khi khởi động"
    echo -e "x-ui disable      - hủy tự khởi động x-ui"
    echo -e "x-ui log          - Xem nhật ký x-ui"
    echo -e "x-ui v2-ui        - Di chuyển dữ liệu tài khoản v2-ui của máy này sang x-ui"
    echo -e "x-ui update       - cập nhật bảng điều khiển x-ui"
    echo -e "x-ui install      - Cài đặt bảng điều khiển x-ui"
    echo -e "x-ui uninstall    - Gỡ cài đặt bảng điều khiển x-ui"
    echo -e "----------------------------------------------"
}

echo -e "${green}bắt đầu cài đặt${plain}"
install_base
install_x-ui $1
