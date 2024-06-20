#!/usr/bin/env python3

import xml.etree.ElementTree as ET
import os

path = input("Введите путь к хранилищу с шаблонами (по умолчанию /mnt/pve/BACKUP/qcow2/DE2024/): ")

if path == '':
    path = "/mnt/pve/BACKUP/qcow2/DE2024/"
else:
    if (not os.path.isdir(path)):   
        print("Хранилище не существует")
        os._exit(1)

nst  = int(input("Введите количество стендов на этой ноде: "))

graph = [] # граф связей машин между собой
vmid  = {} # словарь сопоставлений id машин и их имён
vmbrs = {} # словарь сопоставлений машин и их мостов
vmtp  = [] # все машины (включая WAN) и их типы

INITNUM = 2000 # произвольное начальное значение счетчика для номеров машин
HOSTNAME = os.popen('hostname').read()[:-1] # имя ноды

# вспомогательный словарь соспоставлений шейпов и типов машин
vmtypes = {
             'mxgraph.cisco.routers': 'router',
             'mxgraph.cisco.servers': 'server',
             'mxgraph.cisco.switches': 'switch',
             'mxgraph.cisco.computers_and_peripherals' : 'workstation',
             'cloud': 'internet'
          }

tree = ET.parse('DE-1.drawio')
root = tree.getroot()[0][0][0]

# формируем словарь vmid
for cell in root:
    style = cell.attrib.get('style')
    value = cell.attrib.get('value')
    ident = cell.attrib.get('id')
    if isinstance(style, str):
        part = style.partition('shape=')
        #print (part[2])
        if part[1] != '':
            vmid[ident] = value
            part=(part[2].partition(';')[0].split('.'))
            part=('.'.join(part[:3]))
            
            #Сопоставление устройств и их типов, запись в файл
            vmtp.append((vmid[ident], vmtypes[part]))

#print(vmtp)

# строим граф
for cell in root.findall('mxCell'):
    for geometry in cell.findall('mxGeometry'):
        for point in geometry.findall('mxPoint'):
            if point.attrib.get('as') == 'sourcePoint':
                graph.append((vmid[cell.attrib.get('source')], vmid[cell.attrib.get('target')]))
                break

#print(graph, '\n')

# nbr - это количество мостов на одном стенде без учета моста vmbr0 в WAN
counter = 0
for link in graph:
    if link[0] == 'WAN' or link[1] == 'WAN':
        counter += 1
nbr = len(graph) - counter

# Убираем из vmtp WAN. Он не является машиной и только мешает
vmtp.remove(('WAN', 'internet'))

# код для создания bash-скрипта, развёртывающего i-й стенд на текущей ноде
for i in range(0, nst):
    with open ('run-' + str(i) + '.sh', 'w') as f:
        f.write('#!/bin/bash' + '\n')
        f.write('path="/etc/network/interfaces"' + '\n')
        f.write('nbr=' + str(nbr) + '\n')
        f.write('function deploy_bridges {' + '\n')
        f.write('for (( br=' + str(101 + i * nbr) + '; br <= ' + str(100 + nbr * (i + 1)) + '; br++ ))' + '\n')
        f.write('do' + '\n')
        f.write('echo >> $path' + '\n')
        f.write('echo "auto vmbr$br" >> $path' + '\n')
        f.write('echo "iface vmbr$br" inet manual >> $path' + '\n')
        f.write('echo "bridge-ports none" >> $path' + '\n')
        f.write('echo "bridge-stp off" >> $path' + '\n')
        f.write('echo "bridge-fd 0" >> $path' + '\n')
        f.write('echo >> $path' + '\n')
        f.write('echo "bridge vmbr$br created";' + '\n')
        f.write('done' + '\n')
        f.write('sleep 1' + '\n')
        f.write('systemctl restart networking' + '\n')
        f.write('}' + '\n')
        
        # формируем имя пула
        pool = "pool-" + HOSTNAME + "-" + str(i)
        f.write('pvesh create /pools --poolid ' + pool + '\n') 

        # Мосты для i-го стенда
        bridges = ["vmbr" + str(nb) for nb in range(101 + i * nbr, 101 + nbr * (i + 1))]

        # инициализируем vmbrs для i-го стенда
        for vm in vmtp:
            if vm[0] != 'WAN':
                vmbrs[vm[0]] = []

        # формируем сопоставления машин их мостам
        curbr = 0 # текущий бридж в bridges
        for link in graph:
            if link[0] == 'WAN' or link[1] == 'WAN':
                temp = [link[0], link[1]]
                temp.remove('WAN')
                vmbrs[temp[0]].append('vmbr0')
            else:
                vmbrs[link[0]].append(bridges[curbr])
                vmbrs[link[1]].append(bridges[curbr])
                curbr += 1
        
        # формируем список только машин (без WAN)
        vms = []        
        for vm in vmtp:
            vms.append(vm[0])

        # Цикл по машинам
        for j in range(0, len(vms)):
            net = ""
            brs = vmbrs[vms[j]]
            for br in brs:
                net += "--net" + str(brs.index(br)) + " e1000,bridge=" + br + ",firewall=1 "
            nvm = INITNUM + len(vms) * i + j # номер машины
            f.write('qm create ' + str(nvm) + ' --name "' + str(vms[j]) + '" --pool "' + pool + '" --cores 2 --memory 3072 --ostype l26 --scsihw virtio-scsi-single ' + net + '--vga qxl' + '\n')
            f.write('if [ $? -ne 0 ]; then echo "Ошибка создания ' + str(vms[j]) + ' для стенда №' + str(i) + '"; exit 2; fi' + '\n')
            f.write('sleep 1' + '\n')
            print(vms)
            print(dict(vmtp))                    
            #f.write('qm importdisk ' + str(nvm) + ' ' + path + dict(vmtp)[vms[j]] + '.qcow2 STORAGE --format qcow2' + '\n')

        f.write('function delete {' + '\n')
        f.write('read -p "Укажите номер удаляемого стенда (нумеруются с нуля): " numst' + '\n')
        f.write('max=$(($nbr * $numst))' + '\n')
        f.write('for (( j=$((100 + $max + 1)); j <= $((100 + $max + $nbr)); j++ ))' + '\n')
        f.write('do' + '\n')
        f.write('sed -i "/auto vmbr$j/,+6d" $path' + '\n')
        f.write('done' + '\n')
        f.write('sleep 1' + '\n')
        f.write('systemctl restart networking' + '\n')
        # удаляем ВМ на этом стенде
        f.write('while read vm;' + '\n')
        f.write('do' + '\n')
        f.write('qm stop $vm' + '\n')
        f.write('sleep 1' + '\n')
        f.write('qm destroy $vm' + '\n')
        f.write(' sleep 1' + '\n')
        f.write('echo "ВМ $vm удалена"' + '\n')
        f.write('done < .temp_stand_416_g1_$numst' + '\n')
        f.write('rm .temp_stand_416_g1_$numst' + '\n')
        f.write('pvesh delete /pools/pool-416-g1-node1-$numst' + '\n')
        f.write('echo "Удалили стенд $numst"' + '\n')
        f.write('}' + '\n')
        
        f.write('function run_stand {' + '\n')
        f.write('for n in {0..9}' + '\n')
        f.write('do' + '\n')
        f.write('VM=$((200 + $n + 10 * $i))' + '\n')
        f.write('qm start $VM' + '\n')
        f.write('if [ $? -ne 0 ]; then echo "Не могу запустить ВМ с номером $VM на стенде №$i"; exit 4; fi' + '\n')
        f.write('echo "ВМ с номером $VM на стенде №$i запущена"' + '\n')
        f.write('sleep 2' + '\n')
        f.write(' done' + '\n')
        f.write('}' + '\n')
        
        f.write('function run_stands {' + '\n')
        f.write('for (( i=0; i < $nst; i++ ))' + '\n')
        f.write('do' + '\n')
        f.write('run_stand' + '\n')
        f.write('done' + '\n')
        f.write('}' + '\n')
        
        f.write('clear' + '\n')
        f.write('echo "+=== Сделай выбор ===+"' + '\n')
        f.write('echo "|Развернуть стенд: 1 |"' + '\n')
        f.write('echo "|Удалить стенд: 2    |"' + '\n')
        f.write('echo "+--------------------+"' + '\n')
        f.write('read -p  "Выбор: " choice' + '\n')
        f.write('read -p "Кол-во стендов на этой ноде: " nst' + '\n')
        f.write('case $choice in' + '\n')
        f.write('1)' + '\n')
        f.write('deploy_bridges' + '\n')
        f.write('deploy_stands' + '\n')
        f.write('#run_stands' + '\n')
        f.write(';;' + '\n')
        f.write('2)' + '\n')
        f.write('delete' + '\n')
        f.write(';;' + '\n')
        f.write('*)' + '\n')
        f.write('echo "Нереализуемый выбор"' + '\n')
        f.write('exit 1' + '\n')
        f.write(';;' + '\n')
        f.write('esac' + '\n')
        f.write('' + '\n')
        f.write('' + '\n')
        f.write('' + '\n')
        f.write('' + '\n')
        f.write('' + '\n')
        f.write('' + '\n')
        f.write('' + '\n')
        f.write('' + '\n')
        f.write('' + '\n')
        f.write('' + '\n')
        f.write('' + '\n')
