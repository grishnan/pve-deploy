#!/bin/bash 

# глобальные константы
path="/etc/network/interfaces"
nbr=10 # количество мостов на этом стенде

function deploy_bridges {

    for (( br=1; br <= $(($nst * $nbr)); br++ ))
    do
        echo >> $path
        echo "auto vmbr$br" >> $path
        echo "iface vmbr$br inet manual" >> $path
        echo "	bridge-ports none" >> $path
        echo "	bridge-stp off" >> $path
        echo "	bridge-fd 0" >> $path 
        echo >> $path
        echo "Мост vmbr$br создан";
    done
    
    sleep 1
    systemctl restart networking

}

function deploy_stand {

    # Развертывание GWI
    lbr=vmbr$(($nbr * $i + 3)) # левый интерфейс
    rbr=vmbr$(($nbr * $i + 5)) # правый интерфейс
    nvm=$((200 + 10 * $i))     # номер машины
    qm create $nvm --name "GWI" --cores 1 --memory 1024 --ostype l26 --scsihw virtio-scsi-single --net0 e1000,bridge=$lbr,firewall=1 --net1 e1000,bridge=$rbr,firewall=1 --vga qxl
    if [ $? -ne 0 ]; then echo "Ошибка создания GWI для стенда №$i"; exit 2; fi
    sleep 1
    qm importdisk $nvm /mnt/pve/BACKUP/qcow2/A-2024/GWI.qcow2 STORAGE --format qcow2
    if [ $? -ne 0 ]; then echo "Ошибка импорта диска для GWI на стенде №$i"; exit 3; fi
    sleep 1
    qm set $nvm -ide0 STORAGE:$nvm/vm-$nvm-disk-0.qcow2 --boot order=ide0
    echo "$nvm" >> .temp_stand$i # вносим информацию о ВМ в файл
    echo; echo "ВМ $vm с номером $nvm на стенде №$i развернута"; echo
    
    # Развертывание GWA
    br1=vmbr$(($nbr * $i + 1))
    br2=vmbr$(($nbr * $i + 2))
    br3=vmbr$(($nbr * $i + 3))
    br4=vmbr$(($nbr * $i + 4))
    nvm=$((201 + 10 * $i))     # номер машины
    qm create $nvm --name "GWA" --cores 2 --memory 4096 --ostype l26 --scsihw virtio-scsi-single --net0 e1000,bridge=$br1,firewall=1,macaddr=BC:24:11:0D:15:26 --net1 e1000,bridge=$br2,firewall=1,macaddr=BC:24:11:6B:01:03 --net2 e1000,bridge=$br3,firewall=1,macaddr=BC:24:11:C6:08:99 --net3 e1000,bridge=$br4,firewall=1,macaddr=BC:24:11:75:4B:A8 --vga qxl
    if [ $? -ne 0 ]; then echo "Ошибка создания GWA для стенда №$i"; exit 2; fi
    sleep 1
    qm importdisk $nvm /mnt/pve/BACKUP/qcow2/A-2024/GWA.qcow2 STORAGE --format qcow2
    if [ $? -ne 0 ]; then echo "Ошибка импорта диска для GWA на стенде №$i"; exit 3; fi
    sleep 1
    qm set $nvm -ide0 STORAGE:$nvm/vm-$nvm-disk-0.qcow2 --boot order=ide0
    echo "$nvm" >> .temp_stand$i # вносим информацию о ВМ в файл
    echo; echo "ВМ $vm с номером $nvm на стенде №$i развернута"; echo

    # Развертывание AdminPC
    br=vmbr$(($nbr * $i + 1))
    nvm=$((202 + 10 * $i))     # номер машины
    qm create $nvm --name "AdminPC" --cores 1 --memory 2048 --ostype l26 --scsihw virtio-scsi-single --net0 e1000,bridge=$br,firewall=1 --vga qxl
    if [ $? -ne 0 ]; then echo "Ошибка создания AdminPC для стенда №$i"; exit 2; fi
    sleep 1
    qm importdisk $nvm /mnt/pve/BACKUP/qcow2/A-2024/AdminPC.qcow2 STORAGE --format qcow2
    if [ $? -ne 0 ]; then echo "Ошибка импорта диска для AdminPC на стенде №$i"; exit 3; fi
    sleep 1
    qm set $nvm -ide0 STORAGE:$nvm/vm-$nvm-disk-0.qcow2 --boot order=ide0
    echo "$nvm" >> .temp_stand$i # вносим информацию о ВМ в файл
    echo; echo "ВМ $vm с номером $nvm на стенде №$i развернута"; echo

    # Развертывание WEB
    br=vmbr$(($nbr * $i + 2))
    nvm=$((203 + 10 * $i))     # номер машины
    qm create $nvm --name "WEB" --cores 2 --memory 2048 --ostype l26 --scsihw virtio-scsi-single --net0 e1000,bridge=$br,firewall=1 --vga qxl
    if [ $? -ne 0 ]; then echo "Ошибка создания WEB для стенда №$i"; exit 2; fi
    sleep 1
    qm importdisk $nvm /mnt/pve/BACKUP/qcow2/A-2024/WEB.qcow2 STORAGE --format qcow2
    if [ $? -ne 0 ]; then echo "Ошибка импорта диска для WEB на стенде №$i"; exit 3; fi
    sleep 1
    qm set $nvm -ide0 STORAGE:$nvm/vm-$nvm-disk-0.qcow2 --boot order=ide0
    echo "$nvm" >> .temp_stand$i # вносим информацию о ВМ в файл
    echo; echo "ВМ $vm с номером $nvm на стенде №$i развернута"; echo

    # Развертывание GWB
    ubr=vmbr$(($nbr * $i + 5)) # верхний интерфейс
    lbr=vmbr$(($nbr * $i + 4)) # левый интерфейс
    bbr=vmbr$(($nbr * $i + 6)) # нижний интерфейс
    nvm=$((204 + 10 * $i))     # номер машины
    qm create $nvm --name "GWB" --cores 2 --memory 4096 --ostype l26 --scsihw virtio-scsi-single --net0 e1000,bridge=$ubr,firewall=1,macaddr=BC:24:11:F2:44:72 --net1 e1000,bridge=$lbr,firewall=1,macaddr=BC:24:11:FF:A5:23 --net2 e1000,bridge=$bbr,firewall=1,macaddr=BC:24:11:AF:CB:62 --vga qxl
    if [ $? -ne 0 ]; then echo "Ошибка создания GWB для стенда №$i"; exit 2; fi
    sleep 1
    qm importdisk $nvm /mnt/pve/BACKUP/qcow2/A-2024/GWB.qcow2 STORAGE --format qcow2
    if [ $? -ne 0 ]; then echo "Ошибка импорта диска для GWB на стенде №$i"; exit 3; fi
    sleep 1
    qm set $nvm -ide0 STORAGE:$nvm/vm-$nvm-disk-0.qcow2 --boot order=ide0
    echo "$nvm" >> .temp_stand$i # вносим информацию о ВМ в файл
    echo; echo "ВМ $vm с номером $nvm на стенде №$i развернута"; echo

    # Развертывание SW
    br6=vmbr$(($nbr * $i + 6))
    br7=vmbr$(($nbr * $i + 7))
    br8=vmbr$(($nbr * $i + 8))
    br9=vmbr$(($nbr * $i + 9))
    nvm=$((205 + 10 * $i))
    qm create $nvm --name "SW" --cores 1 --memory 1024 --ostype l26 --scsihw virtio-scsi-single --net0 e1000,bridge=$br6,firewall=1 --net1 e1000,bridge=$br7,firewall=1 --net2 e1000,bridge=$br8,firewall=1 --net3 e1000,bridge=$br9,firewall=1 --vga qxl
    if [ $? -ne 0 ]; then echo "Ошибка создания SW для стенда №$i"; exit 2; fi
    sleep 1
    qm importdisk $nvm /mnt/pve/BACKUP/qcow2/A-2024/SW.qcow2 STORAGE --format qcow2
    if [ $? -ne 0 ]; then echo "Ошибка импорта диска для SW на стенде №$i"; exit 3; fi
    sleep 1
    qm set $nvm -ide0 STORAGE:$nvm/vm-$nvm-disk-0.qcow2 --boot order=ide0
    echo "$nvm" >> .temp_stand$i # вносим информацию о ВМ в файл
    echo; echo "ВМ $vm с номером $nvm на стенде №$i развернута"; echo

    # Развертывание Security01
    br=vmbr$(($nbr * $i + 7))
    nvm=$((206 + 10 * $i))
    qm create $nvm --name "Security01" --cores 1 --memory 2048 --ostype l26 --scsihw virtio-scsi-single --net0 e1000,bridge=$br,firewall=1 --vga qxl
    if [ $? -ne 0 ]; then echo "Ошибка создания Security01 для стенда №$i"; exit 2; fi
    sleep 1
    qm importdisk $nvm /mnt/pve/BACKUP/qcow2/A-2024/Security01.qcow2 STORAGE --format qcow2
    if [ $? -ne 0 ]; then echo "Ошибка импорта диска для Security01 на стенде №$i"; exit 3; fi
    sleep 1
    qm set $nvm -ide0 STORAGE:$nvm/vm-$nvm-disk-0.qcow2 --boot order=ide0
    echo "$nvm" >> .temp_stand$i # вносим информацию о ВМ в файл
    echo; echo "ВМ $vm с номером $nvm на стенде №$i развернута"; echo

    # Развертывание SALES
    br=vmbr$(($nbr * $i + 8))
    nvm=$((207 + 10 * $i))
    qm create $nvm --name "SALES" --cores 2 --memory 4096 --ostype l26 --scsihw virtio-scsi-single --net0 e1000,bridge=$br,firewall=1 --net1 e1000,bridge=vmbr0,firewall=1 --vga qxl
    if [ $? -ne 0 ]; then echo "Ошибка создания SALES для стенда №$i"; exit 2; fi
    sleep 1
    qm importdisk $nvm /mnt/pve/BACKUP/qcow2/A-2024/SALES.qcow2 STORAGE --format qcow2
    if [ $? -ne 0 ]; then echo "Ошибка импорта диска для SALES на стенде №$i"; exit 3; fi
    sleep 1
    qm set $nvm -ide0 STORAGE:$nvm/vm-$nvm-disk-0.qcow2 --boot order=ide0
    echo "$nvm" >> .temp_stand$i # вносим информацию о ВМ в файл
    echo; echo "ВМ $vm с номером $nvm на стенде №$i развернута"; echo

    # Развертывание SW-P
    br9=vmbr$(($nbr * $i + 9))
    br10=vmbr$(($nbr * $i + 10))
    nvm=$((208 + 10 * $i))
    qm create $nvm --name "SW-P" --cores 1 --memory 1024 --ostype l26 --scsihw virtio-scsi-single --net0 e1000,bridge=$br9,firewall=1 --net1 e1000,bridge=$br10,firewall=1 --vga qxl
    if [ $? -ne 0 ]; then echo "Ошибка создания SW-P для стенда №$i"; exit 2; fi
    sleep 1
    qm importdisk $nvm /mnt/pve/BACKUP/qcow2/A-2024/SW-P.qcow2 STORAGE --format qcow2
    if [ $? -ne 0 ]; then echo "Ошибка импорта диска для SW-P на стенде №$i"; exit 3; fi
    sleep 1
    qm set $nvm -ide0 STORAGE:$nvm/vm-$nvm-disk-0.qcow2 --boot order=ide0
    echo "$nvm" >> .temp_stand$i # вносим информацию о ВМ в файл
    echo; echo "ВМ $vm с номером $nvm на стенде №$i развернута"; echo

    # Развертывание PUBLIC
    br=vmbr$(($nbr * $i + 10))
    nvm=$((209 + 10 * $i))
    qm create $nvm --name "PUBLIC" --cores 1 --memory 2048 --ostype l26 --scsihw virtio-scsi-single --net0 e1000,bridge=$br,firewall=1 --vga qxl
    if [ $? -ne 0 ]; then echo "Ошибка создания PUBLIC для стенда №$i"; exit 2; fi
    sleep 1
    qm importdisk $nvm /mnt/pve/BACKUP/qcow2/A-2024/PUBLIC.qcow2 STORAGE --format qcow2
    if [ $? -ne 0 ]; then echo "Ошибка импорта диска для PUBLIC на стенде №$i"; exit 3; fi
    sleep 1
    qm set $nvm -ide0 STORAGE:$nvm/vm-$nvm-disk-0.qcow2 --boot order=ide0
    echo "$nvm" >> .temp_stand$i # вносим информацию о ВМ в файл
    echo; echo "ВМ $vm с номером $nvm на стенде №$i развернута"; echo
}

function deploy_stands {

    for (( i=0; i < $nst; i++ ))
    do
        deploy_stand
    done
}

function delete {
    read -p "Укажите номер удаляемого стенда (нумеруются с нуля): " numst
    max=$(($nbr * $numst))
    for (( j=$(($max + 1)); j <= $(($max + $nbr)); j++ ))
    do
        sed -i "/auto vmbr$j/,+6d" $path                
    done
    sleep 1
    systemctl restart networking
    
    # удаляем ВМ на этом стенде
    while read vm;
    do
        qm stop $vm
        sleep 1
        qm destroy $vm
        sleep 1
        echo "ВМ $vm удалена"
    done < .temp_stand$numst

    rm .temp_stand$numst # удаляем временный файл с номерами ВМ на текущем стенде
    echo "Удалили стенд $numst"
}

function run_stand {
    for n in {0..9}
    do
        VM=$((200 + $n + 10 * $i))
        qm start $VM
        if [ $? -ne 0 ]; then echo "Не могу запустить ВМ с номером $VM на стенде №$i"; exit 4; fi
        echo "ВМ с номером $VM на стенде №$i запущена"
        sleep 2
    done
}

function run_stands {

    for (( i=0; i < $nst; i++ ))
    do
        run_stand
    done

}

clear
echo "+=== Сделай выбор ===+"
echo "|Развернуть стенд: 1 |"
echo "|Удалить стенд: 2    |"
echo "+--------------------+"
read -p  "Выбор: " choice
read -p "Кол-во стендов на этой ноде: " nst

case $choice in
    1)
        deploy_bridges
        deploy_stands
        #run_stands
    ;;
    2)
        delete
    ;;
    *)
        echo "Нереализуемый выбор"
        exit 1
    ;;
esac
