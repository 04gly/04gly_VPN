#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "Hãy chạy ở quyền root!\n" && exit 1

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
    LOGE "Phiên bản hệ thống không được phát hiện,！\n" && exit 1
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
        LOGE "请使用 CentOS 7 或更高版本的系统！\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        LOGE "请使用 Ubuntu 16 或更高版本的系统！\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        LOGE "请使用 Debian 8 或更高版本的系统！\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Có khởi động lại bảng điều khiển hay không, khởi động lại bảng điều khiển cũng sẽ khởi động lại xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn enter để quay lại menu chính: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/04gly/04gly_VPN/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "Chức năng này sẽ buộc cài đặt lại phiên bản mới nhất và dữ liệu sẽ không bị mất. Bạn có muốn tiếp tục không?" "n"
    if [[ $? != 0 ]]; then
        LOGE "已取消"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/04gly/04gly_VPN/main/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "Cập nhật hoàn tất và bảng điều khiển đã tự động khởi động lại "
        exit 0
    fi
}

uninstall() {
    confirm "Bạn có chắc chắn muốn gỡ cài đặt bảng điều khiển,xray Nó cũng sẽ được gỡ cài đặt chứ?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "Quá trình gỡ cài đặt thành công. Nếu bạn muốn xóa tập lệnh này, hãy chạy nó sau khi thoát khỏi tập lệnh ${green}rm /usr/bin/x-ui -f${plain} xóa"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Đảm bảo rằng bạn muốn đặt lại tên người dùng và mật khẩu của mình thành admin" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "Tên người dùng và mật khẩu đã được đặt lại thành ${green}admin${plain}，Vui lòng khởi động lại bảng điều khiển ngay bây giờ"
    confirm_restart
}

reset_config() {
    confirm "Bạn có chắc chắn muốn đặt lại tất cả cài đặt bảng điều khiển, dữ liệu tài khoản sẽ không bị mất, tên người dùng và mật khẩu sẽ không thay đổi" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "Tất cả cài đặt bảng điều khiển đã được đặt lại về mặc định, vui lòng khởi động lại bảng điều khiển ngay bây giờ và sử dụng mặc định ${green}54321${plain} Bảng truy cập cổng"
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "get current settings error,please check logs"
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "Nhập số cổng [1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "Đã hủy"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "Sau khi cài đặt cổng, vui lòng khởi động lại bảng điều khiển ngay bây giờ và sử dụng cổng mới được đặt ${green}${port}${plain} bảng truy cập"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "Bảng điều khiển đã chạy và không cần khởi động lại, nếu cần khởi động lại, vui lòng chọn Khởi động lại"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui Bắt đầu thành công"
        else
            LOGE "Bảng điều khiển không khởi động được, có thể do thời gian khởi động vượt quá hai giây, vui lòng kiểm tra thông tin nhật ký sau"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "Bảng điều khiển đã dừng, không cần dừng lại"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui và xray dừng thành công"
        else
            LOGE "Bảng điều khiển không dừng được, có thể do thời gian dừng vượt quá hai giây, vui lòng kiểm tra thông tin nhật ký sau"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui và xray khởi động lại thành công"
    else
        LOGE "Bảng điều khiển không thể khởi động lại, có thể do thời gian khởi động vượt quá hai giây, vui lòng kiểm tra thông tin nhật ký sau"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui Set boot tự khởi động thành công"
    else
        LOGE "x-ui Không đặt được tự động khởi động"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui Hủy khởi động tự động thành công"
    else
        LOGE "x-ui Không thể hủy tự khởi động"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # dang cai dat bbr
    bash <(curl -L -s https://raw.githubusercontent.com/04gly/04glyph/main/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://raw.githubusercontent.com/04gly/04gly_VPN/main/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "Không thể tải xuống tập lệnh, vui lòng kiểm tra xem máy có thể kết nối với Github không"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "Tập lệnh nâng cấp đã thành công, vui lòng chạy lại tập lệnh" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "Bảng điều khiển đã được cài đặt, vui lòng không lặp lại cài đặt"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "Vui lòng cài đặt bảng điều khiển trước"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "Trạng thái bảng điều khiển: ${green}đã được chạy${plain}"
        show_enable_status
        ;;
    1)
        echo -e "Trạng thái bảng điều khiển: ${yellow}không chạy${plain}"
        show_enable_status
        ;;
    2)
        echo -e "Trạng thái bảng điều khiển: ${red}Chưa cài đặt${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Có tự khởi động sau khi khởi động hay không: ${green}是${plain}"
    else
        echo -e "Có tự khởi động sau khi khởi động hay không: ${red}否${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray tình trạng: ${green}chạy${plain}"
    else
        echo -e "xray tình trạng: ${red}không chạy${plain}"
    fi
}

ssl_cert_issue() {
    echo -E ""
    LOGD "******Hướng dẫn sử dụng******"
    LOGI "Tập lệnh này sẽ sử dụng tập lệnh Acme để đăng ký chứng chỉ, khi sử dụng bạn cần đảm bảo:"
    LOGI "1. Biết địa chỉ email đã đăng ký Cloudflare"
    LOGI "2. Biết khóa API toàn cầu của Cloudflare"
    LOGI "3. Tên miền đã được Cloudflare phân giải về máy chủ hiện tại"
    LOGI "4. Đường dẫn cài đặt mặc định của tập lệnh để đăng ký chứng chỉ là thư mục /root/cert"
    confirm "Tôi đã xác nhận [y/n]" "y"
    if [ $? -eq 0 ]; then
        cd ~
        LOGI "Cài đặt Acme-Script"
        curl https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            LOGE "Không thể cài đặt tập lệnh acme"
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
        LOGD "Vui lòng đặt tên miền:"
        read -p "Input your domain here:" CF_Domain
        LOGD "Tên miền của bạn được đặt thành:${CF_Domain}"
        LOGD "Vui lòng đặt khóa API:"
        read -p "Input your key here:" CF_GlobalKey
        LOGD "Khóa API của bạn là:${CF_GlobalKey}"
        LOGD "Vui lòng thiết lập địa chỉ email đã đăng ký của bạn:"
        read -p "Input your email here:" CF_AccountEmail
        LOGD "Địa chỉ email đã đăng ký của bạn là:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "Sửa đổi CA mặc định thành Lets'Encrypt không thành công, tập lệnh thoát"
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "Cấp chứng chỉ không thành công, tập lệnh đã thoát"
            exit 1
        else
            LOGI "Đã cấp chứng chỉ thành công, đang cài đặt..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "Cài đặt chứng chỉ không thành công, tập lệnh đã thoát"
            exit 1
        else
            LOGI "Chứng chỉ đã được cài đặt thành công và cập nhật tự động được bật..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "Thiết lập tự động cập nhật không thành công, tập lệnh đã thoát"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "Chứng chỉ đã được cài đặt và kích hoạt tự động gia hạn, thông tin cụ thể như sau"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

show_usage() {
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

show_menu() {
    echo -e "
  ${green}x-ui Tập lệnh quản lý bảng điều khiển${plain}
  ${green}0.${plain} thoát kịch bản
————————————————
  ${green}1.${plain} cài đặt x-ui
  ${green}2.${plain} cập nhật x-ui
  ${green}3.${plain} gỡ cài đặt x-ui
————————————————
  ${green}4.${plain} Đặt lại tên người dùng và mật khẩu
  ${green}5.${plain} Đặt lại cài đặt bảng điều khiển
  ${green}6.${plain} Đặt cổng bảng điều khiển
  ${green}7.${plain} Xem cài đặt bảng điều khiển hiện tại
————————————————
  ${green}8.${plain} bắt đầu x-ui
  ${green}9.${plain} dừng x-ui
  ${green}10.${plain} khởi động lại x-ui
  ${green}11.${plain} Xem trạng thái x-ui
  ${green}12.${plain} Xem nhật ký x-ui
————————————————
  ${green}13.${plain} Đặt x-ui tự khởi động khi khởi động
  ${green}14.${plain} hủy tự khởi động x-ui
————————————————
  ${green}15.${plain} Cài đặt bằng một cú nhấp chuột bbr (kernel mới nhất)
  ${green}16.${plain} Ứng dụng một cú nhấp chuột cho chứng chỉ SSL (ứng dụng acme)
 "
    show_status
    echo && read -p "Vui lòng nhập lựa chọn [0-16]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        install_bbr
        ;;
    16)
        ssl_cert_issue
        ;;
    *)
        LOGE "Vui lòng nhập số chính xác [0-16]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
