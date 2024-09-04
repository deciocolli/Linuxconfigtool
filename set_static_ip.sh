#!/bin/bash

# Função para detectar a distribuição Linux
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    elif type lsb_release >/dev/null 2>&1; then
        DISTRO=$(lsb_release -si)
    elif [ -f /etc/debian_version ]; then
        DISTRO=Debian
    elif [ -f /etc/redhat-release ]; then
        DISTRO=RedHat
    else
        DISTRO=$(uname -s)
    fi
    echo $DISTRO
}

# Lista interfaces de rede ativas
echo "Interfaces de rede ativas:"
ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"

# Solicita ao usuário para escolher uma interface
read -p "Digite o nome da interface que deseja configurar: " INTERFACE

# Obtém o IP atual, máscara de rede e gateway da interface escolhida
CURRENT_IP=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
NETMASK=$(ifconfig $INTERFACE | grep -w "inet" | awk '{print $4}')
GATEWAY=$(ip route | grep default | awk '{print $3}')

# Verifica se a interface escolhida é válida
if [ -z "$CURRENT_IP" ]; then
    echo "Interface inválida ou sem IP atribuído."
    exit 1
fi

# Pergunta ao usuário se deseja usar o IP atual ou inserir manualmente
echo "Configuração atual da interface $INTERFACE:"
echo "IP: $CURRENT_IP"
echo "Máscara de Rede: $NETMASK"
echo "Gateway: $GATEWAY"
read -p "Deseja usar o IP atual obtido via DHCP? (s/n): " USE_DHCP_IP

if [ "$USE_DHCP_IP" != "s" ]; then
    read -p "Digite o IP estático desejado: " CURRENT_IP
    read -p "Digite a máscara de rede (ex: 255.255.255.0): " NETMASK
    read -p "Digite o gateway: " GATEWAY
fi

# Solicita ao usuário para inserir os servidores DNS
read -p "Digite o(s) servidor(es) DNS separados por espaço (ex: 8.8.8.8 8.8.4.4): " DNS_SERVERS

# Detecta a distribuição Linux
DISTRO=$(detect_distro)

# Backup do arquivo de configuração atual com data e hora
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Configurações específicas para cada distribuição
case $DISTRO in
    ubuntu|debian)
        sudo cp /etc/network/interfaces /etc/network/interfaces.bak_$TIMESTAMP
        sudo bash -c "cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto $INTERFACE
iface $INTERFACE inet static
    address $CURRENT_IP
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers $DNS_SERVERS
EOF"
        sudo systemctl restart networking
        ;;
    centos|fedora|rhel)
        sudo cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACE /etc/sysconfig/network-scripts/ifcfg-$INTERFACE.bak_$TIMESTAMP
        sudo bash -c "cat > /etc/sysconfig/network-scripts/ifcfg-$INTERFACE <<EOF
DEVICE=$INTERFACE
BOOTPROTO=none
ONBOOT=yes
IPADDR=$CURRENT_IP
NETMASK=$NETMASK
GATEWAY=$GATEWAY
DNS1=$(echo $DNS_SERVERS | awk '{print $1}')
DNS2=$(echo $DNS_SERVERS | awk '{print $2}')
EOF"
        sudo systemctl restart network
        ;;
    *)
        echo "Distribuição Linux não suportada pelo script."
        exit 1
        ;;
esac

echo "Configuração de IP estático e DNS aplicada com sucesso na interface $INTERFACE. IP: $CURRENT_IP, DNS: $DNS_SERVERS"
echo "Backup criado: /etc/network/interfaces.bak_$TIMESTAMP ou /etc/sysconfig/network-scripts/ifcfg-$INTERFACE.bak_$TIMESTAMP"
