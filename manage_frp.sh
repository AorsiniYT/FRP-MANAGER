#!/bin/bash

# Función para obtener la última versión de FRP desde GitHub
get_latest_version() {
    curl --silent "https://api.github.com/repos/fatedier/frp/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")'
}

# Obtener la última versión
latest_version=$(get_latest_version)
frp_url="https://github.com/fatedier/frp/releases/download/${latest_version}/frp_${latest_version#v}_linux_amd64.tar.gz"
install_dir="/root/FRP"
version_file="${install_dir}/version.txt"

# Función para instalar FRP
install_frp() {
    # Descargar la última versión de FRP
    wget $frp_url -O /tmp/frp_latest.tar.gz

    # Extraer los archivos descargados
    tar -xzf /tmp/frp_latest.tar.gz -C /tmp/

    # Crear el directorio de destino si no existe
    mkdir -p $install_dir

    # Copiar los binarios frps y frpc al directorio de destino
    cp /tmp/frp_${latest_version#v}_linux_amd64/frps $install_dir/
    cp /tmp/frp_${latest_version#v}_linux_amd64/frpc $install_dir/

    # Guardar la versión instalada
    echo $latest_version > $version_file

    # Comprobar la presencia de los archivos de configuración
    while [[ ! -f /root/frps.toml || ! -f /root/frpc.toml ]]; do
        echo "Esperando que los archivos frps.toml y frpc.toml estén en el directorio /root."
        read -p "Presiona Enter para continuar una vez que los archivos estén presentes..."
    done

    # Reemplazar los archivos de configuración en /root/FRP
    cp /root/frps.toml $install_dir/
    cp /root/frpc.toml $install_dir/
}

# Función para actualizar FRP
update_frp() {
    if [[ -f $version_file ]]; then
        current_version=$(cat $version_file)
        if [[ $current_version == $latest_version ]]; then
            echo "FRP ya está actualizado a la última versión ($current_version)."
            exit 0
        fi
    fi

    echo "Actualizando FRP a la última versión ($latest_version)..."
    install_frp

    # Reiniciar el servicio si existe
    if systemctl is-active --quiet frpc.service; then
        sudo systemctl stop frpc.service
        sudo systemctl disable frpc.service
        create_service frpc
        sudo systemctl enable frpc.service
        sudo systemctl start frpc.service
        echo "Servicio frpc actualizado y reiniciado."
    elif systemctl is-active --quiet frps.service; then
        sudo systemctl stop frps.service
        sudo systemctl disable frps.service
        create_service frps
        sudo systemctl enable frps.service
        sudo systemctl start frps.service
        echo "Servicio frps actualizado y reiniciado."
    fi

    echo "Actualización de FRP completada."
}

# Función para crear el servicio systemd
create_service() {
    if [[ $1 == "frps" ]]; then
        sudo bash -c 'cat << EOF > /etc/systemd/system/frps.service
[Unit]
Description=FRP Server Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/root/FRP/frps -c /root/FRP/frps.toml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF'
        sudo systemctl enable frps.service
        sudo systemctl start frps.service
        echo "Servicio frps habilitado y iniciado."
    elif [[ $1 == "frpc" ]]; then
        sudo bash -c 'cat << EOF > /etc/systemd/system/frpc.service
[Unit]
Description=FRP Client Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/root/FRP/frpc -c /root/FRP/frpc.toml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF'
        sudo systemctl enable frpc.service
        sudo systemctl start frpc.service
        echo "Servicio frpc habilitado y iniciado."
    else
        echo "Opción no válida. Elige 'frps' o 'frpc'."
    fi
}

# Preguntar si se desea instalar o actualizar FRP
echo "Selecciona una opción:"
echo "1) Instalar"
echo "2) Actualizar"
read -p "Introduce el número de tu elección (1 o 2): " action

case $action in
    1)
        install_frp
        # Preguntar si se habilitará frps (servidor) o frpc (cliente)
        echo "Selecciona la opción que deseas habilitar:"
        echo "1) frps (servidor)"
        echo "2) frpc (cliente)"
        read -p "Introduce el número de tu elección (1 o 2): " choice

        # Crear el servicio systemd para frps o frpc
        if [[ $choice -eq 1 ]]; then
            create_service frps
        elif [[ $choice -eq 2 ]]; then
            create_service frpc
        else
            echo "Opción no válida. Por favor, ejecuta el script de nuevo y elige '1' o '2'."
        fi
        ;;
    2)
        update_frp
        ;;
    *)
        echo "Opción no válida. Por favor, ejecuta el script de nuevo y elige '1' o '2'."
        ;;
esac

echo "Operación completada."

