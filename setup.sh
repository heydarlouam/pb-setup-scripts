#!/bin/bash

# اسکریپت نصب کامل پاکت بیس - فقط یک دستور!
# Usage: curl -sSL https://raw.githubusercontent.com/heydarlouam/pb-setup-scripts/main/setup.sh | bash

set -e  # اگر خطایی اتفاق بیفتد اسکریپت متوقف شود

# رنگ‌ها برای خروجی زیباتر
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color - برای بازگشت به رنگ عادی

# توابع برای نمایش پیام‌های مختلف
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }        # پیام‌های عادی
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }              # پیام‌های خطا
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }               # اخطارها
info() { echo -e "${BLUE}[INFO]${NC} $1"; }                       # اطلاعات

# نمایش بنر زیبا
show_banner() {
    echo -e "${GREEN}"
    cat << "EOF"
    
███╗   ███╗███████╗███╗   ██╗██╗   ██╗███╗   ███╗██╗████████╗ █████╗ 
████╗ ████║██╔════╝████╗  ██║██║   ██║████╗ ████║██║╚══██╔══╝██╔══██╗
██╔████╔██║█████╗  ██╔██╗ ██║██║   ██║██╔████╔██║██║   ██║   ███████║
██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║   ██║██║╚██╔╝██║██║   ██║   ██╔══██║
██║ ╚═╝ ██║███████╗██║ ╚████║╚██████╔╝██║ ╚═╝ ██║██║   ██║   ██║  ██║
╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝╚═╝   ╚═╝   ╚═╝  ╚═╝
                                                                      
    🍽️  Auto Deployer - One Command Setup 🚀
EOF
    echo -e "${NC}"
}

# دریافت ساب دامین از کاربر
get_subdomain() {
    echo -e "${YELLOW}🌐 لطفاً ساب دامین مورد نظر را وارد کنید:${NC}"
    echo -e "${BLUE}مثال: pb, admin, api${NC}"
    read -p "ساب دامین: " SUBDOMAIN
    
    if [ -z "$SUBDOMAIN" ]; then
        error "ساب دامین نمی‌تواند خالی باشد"
    fi
    
    DOMAIN="${SUBDOMAIN}.frozencoffee.ir"
    log "دامین تنظیم شد: $DOMAIN"
}

# بررسی اینکه اسکریپت با دسترسی root اجرا شده
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "لطفاً با دستور sudo اجرا کنید: sudo bash setup.sh"
    fi
}

# آپدیت سیستم و نصب آپدیت‌های موجود
update_system() {
    log "آپدیت سیستم..."
    apt update && apt upgrade -y
}

# نصب تمام وابستگی‌های مورد نیاز
install_dependencies() {
    log "نصب وابستگی‌ها..."
    apt install -y curl wget unzip nginx certbot python3-certbot-nginx
}

# دانلود و نصب پاکت بیس
install_pocketbase() {
    log "نصب پاکت بیس..."
    mkdir -p /root/pocketbase  # ایجاد پوشه پاکت بیس
    cd /root/pocketbase
    
    PB_VERSION="0.22.21"  # نسخه پاکت بیس
    rm -f pocketbase*  # پاک کردن فایل‌های قبلی
    
    # دانلود پاکت بیس
    curl -L -o pocketbase_${PB_VERSION}_linux_amd64.zip \
        "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip"
    
    # اکسترکت فایل زیپ
    unzip pocketbase_${PB_VERSION}_linux_amd64.zip
    rm pocketbase_${PB_VERSION}_linux_amd64.zip  # پاک کردن فایل زیپ
    chmod +x pocketbase  # دادن مجوز اجرا
    
    log "پاکت بیس نصب شد"
}

# ایجاد سرویس systemd برای مدیریت پاکت بیس
create_service() {
    log "ایجاد سرویس systemd..."
    
    # ایجاد فایل سرویس
    cat > /etc/systemd/system/pocketbase.service << EOF
[Unit]
Description=PocketBase Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/pocketbase
ExecStart=/root/pocketbase/pocketbase serve --http="0.0.0.0:8090"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload  # بارگذاری مجدد سرویس‌ها
    systemctl enable pocketbase.service  # فعال کردن سرویس
    log "سرویس ایجاد شد"
}

# تنظیم nginx به عنوان reverse proxy
setup_nginx() {
    log "تنظیم nginx برای $DOMAIN..."
    
    # ایجاد کانفیگ nginx
    cat > /etc/nginx/sites-available/${DOMAIN} << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # فعال‌سازی سایت
    ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default  # حذف کانفیگ پیش‌فرض
    
    # تست و reload nginx
    nginx -t && systemctl reload nginx
    log "nginx تنظیم شد"
}

# نصب SSL رایگان با Let's Encrypt
setup_ssl() {
    log "نصب SSL برای $DOMAIN..."
    warning "لطفاً مطمئن شوید Cloudflare روی DNS-only باشد"
    read -p "آماده‌اید؟ (Enter) " -n 1 -r
    
    # دریافت SSL certificate
    certbot --nginx -d $DOMAIN --non-interactive --agree-tos \
        --email phone.sync.heydarloo@gmail.com --redirect
    log "SSL نصب شد"
}

# دانلود و restore backup از GitHub
restore_backup() {
    log "دانلود و restore backup..."
    
    cd /root/pocketbase
    
    # دانلود backup از GitHub
    BACKUP_URL="https://github.com/heydarlouam/pb-setup-scripts/raw/main/pocketbase_backup.zip"
    
    if curl -L -o backup.zip "$BACKUP_URL"; then
        log "Backup دانلود شد"
    else
        error "خطا در دانلود backup"
    fi
    
    # توقف سرویس برای restore
    systemctl stop pocketbase.service
    
    # اکسترکت backup
    unzip -o backup.zip
    rm backup.zip  # پاک کردن فایل زیپ
    
    # راه‌اندازی مجدد سرویس
    systemctl start pocketbase.service
    
    log "Backup restore شد"
}

# بررسی وضعیت نهایی سرویس‌ها
check_final_status() {
    log "بررسی وضعیت نهایی..."
    sleep 5  # منتظر می‌ماند تا سرویس‌ها کاملاً راه‌اندازی شوند
    
    echo -e "\n${GREEN}✅ وضعیت سرویس‌ها:${NC}"
    systemctl status pocketbase.service --no-pager
    
    echo -e "\n${GREEN}🌐 تست دسترسی:${NC}"
    if curl -s -I https://$DOMAIN/ > /dev/null; then
        log "دسترسی به $DOMAIN برقرار است"
    else
        warning "مشکل در دسترسی به $DOMAIN"
    fi
}

# نمایش اطلاعات نهایی و راهنما
show_success() {
    echo -e "\n${GREEN}"
    echo "🎉 🎉 🎉 نصب کامل شد! 🎉 🎉 🎉"
    echo -e "${NC}"
    
    echo -e "${YELLOW}📋 اطلاعات دسترسی:${NC}"
    echo -e "🌐 آدرس اصلی: ${GREEN}https://$DOMAIN${NC}"
    echo -e "🔧 پنل ادمین: ${GREEN}https://$DOMAIN/_/${NC}"
    echo -e "📚 API: ${GREEN}https://$DOMAIN/api/${NC}"
    
    echo -e "\n${YELLOW}⚙️  دستورات مدیریتی:${NC}"
    echo -e "وضعیت: ${GREEN}systemctl status pocketbase${NC}"
    echo -e "رستارت: ${GREEN}systemctl restart pocketbase${NC}"
    echo -e "لاگ: ${GREEN}journalctl -u pocketbase -f${NC}"
    
    echo -e "\n${GREEN}✅ همه چیز آماده است!${NC}"
}

# تابع اصلی که تمام مراحل را به ترتیب اجرا می‌کند
main() {
    show_banner           # نمایش بنر
    get_subdomain         # دریافت ساب دامین
    check_root            # بررسی دسترسی root
    
    log "شروع فرآیند نصب برای $DOMAIN..."
    
    # اجرای مراحل به ترتیب
    update_system         # آپدیت سیستم
    install_dependencies  # نصب وابستگی‌ها
    install_pocketbase    # نصب پاکت بیس
    create_service        # ایجاد سرویس
    setup_nginx          # تنظیم nginx
    setup_ssl            # نصب SSL
    restore_backup       # restore backup
    check_final_status   # بررسی وضعیت نهایی
    show_success         # نمایش پیام موفقیت
}

# اجرای تابع اصلی
main "$@"