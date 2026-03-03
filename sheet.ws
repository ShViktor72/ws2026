# ============================================
# WORLD SKILLS ALMATY 2026 - МОДУЛЬ А
# ИНТЕРНЕТ-ШПАРГАЛКА
# ============================================

# --- 1. ПРОВЕРКА СЕТИ ---
ip a
ip route
ping 8.8.8.8
ping6 2001:db8:1111::1

# --- 2. LDAP (int-srv01) ---
# Установка
sudo apt install -y slapd ldap-utils

# Перенастройка домена
sudo dpkg-reconfigure slapd
# Ответы: DNS domain = int.ws.kz, Organization = WS, Password = Skill39!

# Проверка текущего домена
sudo ldapsearch -x -LLL -b "" -s base namingContexts

# Просмотр всех записей
sudo slapcat | less

# Структура OU (файл base.ldif)
cat > /tmp/base.ldif << 'EOF'
dn: ou=People,dc=int,dc=ws,dc=kz
objectClass: organizationalUnit
ou: People

dn: ou=Group,dc=int,dc=ws,dc=kz
objectClass: organizationalUnit
ou: Group

dn: ou=Employees,ou=People,dc=int,dc=ws,dc=kz
objectClass: organizationalUnit
ou: Employees
EOF

# Добавление OU
ldapadd -x -D cn=admin,dc=int,dc=ws,dc=kz -W -f /tmp/base.ldif

# Проверка
ldapsearch -x -b "dc=int,dc=ws,dc=kz" ou

# --- 3. ДОБАВЛЕНИЕ ПОЛЬЗОВАТЕЛЕЙ (Таблица 2) ---
cat > /tmp/users.ldif << 'EOF'
dn: uid=jamie,ou=Employees,ou=People,dc=int,dc=ws,dc=kz
objectClass: inetOrgPerson
objectClass: posixAccount
uid: jamie
cn: Jamie Oliver
sn: Oliver
givenName: Jamie
mail: jamie.oliver@dmz.ws.kz
userPassword: {CRYPT}Skill39!
uidNumber: 10001
gidNumber: 5000
homeDirectory: /home/jamie
loginShell: /bin/bash

dn: uid=peter,ou=Employees,ou=People,dc=int,dc=ws,dc=kz
objectClass: inetOrgPerson
objectClass: posixAccount
uid: peter
cn: Peter Fox
sn: Fox
givenName: Peter
mail: peter.fox@dmz.ws.kz
userPassword: {CRYPT}Skill39!
uidNumber: 10002
gidNumber: 5000
homeDirectory: /home/peter
loginShell: /bin/bash

dn: uid=admin,dc=int,dc=ws,dc=kz
objectClass: inetOrgPerson
objectClass: posixAccount
uid: admin
cn: Administrator
sn: Administrator
givenName: Admin
userPassword: {CRYPT}Skill39!
uidNumber: 10000
gidNumber: 5000
homeDirectory: /home/admin
loginShell: /bin/bash
EOF

ldapadd -x -D cn=admin,dc=int,dc=ws,dc=kz -W -f /tmp/users.ldif

# --- 4. СЛУЖЕБНАЯ ЗАПИСЬ ДЛЯ DNS ---
# Будет добавлено позже

# --- 5. SAMBA ---
sudo apt install -y samba
sudo smbpasswd -a jamie  # пароль Skill39!
sudo smbpasswd -e jamie

# Настройка шар (редактировать /etc/samba/smb.conf)
# [public]
#   path = /srv/samba/public
#   browseable = yes
#   read only = no
#   guest ok = yes
#   create mask = 0755

# [internal]
#   path = /srv/samba/internal
#   browseable = no
#   read only = no
#   guest ok = no
#   valid users = jamie
#   create mask = 0700

# Проверка конфига
testparm

# --- 6. DNS (BIND9) ---
sudo apt install -y bind9 bind9utils

# Конфигурация зоны int.ws.kz
sudo nano /etc/bind/db.int.ws.kz
# (содержимое зоны)

# Проверка
sudo named-checkconf
sudo named-checkzone int.ws.kz /etc/bind/db.int.ws.kz

# --- 7. CA (OpenSSL) ---
# Создание корневого CA
mkdir -p ~/ca/{root,intermediate,newcerts,certs,crl,private}
cd ~/ca
echo '01' > serial
echo '01' > crlnumber
touch index.txt

# Конфиг openssl для корневого CA
cat > root-ca.conf << 'EOF'
[ req ]
distinguished_name = req_distinguished_name
prompt = no
x509_extensions = v3_ca

[ req_distinguished_name ]
CN = WS Root CA

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:TRUE, pathlen:1
keyUsage = critical, keyCertSign, cRLSign
EOF

# Генерация корневого ключа и сертификата
openssl genrsa -out private/ca.key 4096
openssl req -new -x509 -days 3650 -key private/ca.key -out ca.pem -config root-ca.conf