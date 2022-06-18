#!/usr/bin/env python

import os
import sys
import subprocess

#---------------------------------------thread_csv.py begin----------------------------------------------
import threading
import time
#from IPython.display import clear_output
import ctypes
import inspect
from csv_file import CsvFile

def _async_raise(tid, exctype):
    tid = ctypes.c_long(tid)
    if not inspect.isclass(exctype):
        exctype = type(exctype)
    res = ctypes.pythonapi.PyThreadState_SetAsyncExc(tid, ctypes.py_object(exctype))
    if res == 0:
        raise ValueError("invalid thread id")
    elif res != 1:
        ctypes.pythonapi.PyThreadState_SetAsyncExc(tid, None)
        raise SystemError("PyThreadState_SetAsyncExc failed")
        
def stop_thread(thread):
    _async_raise(thread.ident, SystemExit)

def getInfo4():
    save_dir = 'benchmark_record/'
    max_store = 2520000
    f = CsvFile(save_dir,max_store,first_row=['CPU温度','GPU温度','目前整体功耗(毫瓦)','平均整体功耗(毫瓦)'])
    f.time_to_create_csv()
    count_print = 0
    #count_print_list = ['CPU温度        |','GPU温度        |','实时功耗(毫瓦) |','平均功耗(毫瓦) |']
    #count_print_list = ['Core Temp']
    list_temperature = []
    time.sleep(30)
    while True:
        count_print += 1
        if count_print == 5:
            count_print = 0
            #s1 = ''
            s2 = ''
            #for i in range(0, 1):
            #s1 += str(count_print_list[i])
            s2 += '核心温度: ' + str(list_temperature[0])
            #print(s1)
            print(s2)

        time.sleep(0.5)
        list_temperature = []
        command = 'cat /sys/class/thermal/thermal_zone1/temp'
        command = command.split()
        cmd2 = subprocess.Popen( command, stdout=subprocess.PIPE)
        device_type_str = cmd2.stdout.read()
        device_type_str = str(device_type_str)
        temp = device_type_str[2:-3]
        cpu_temp = str(int(temp)/1000)
        list_temperature.append(cpu_temp)
        
        """command = 'cat /sys/class/thermal/thermal_zone2/temp'
        command = command.split()
        cmd2 = subprocess.Popen( command, stdout=subprocess.PIPE)
        device_type_str = cmd2.stdout.read()
        device_type_str = str(device_type_str)
        temp = device_type_str[2:-3]
        gpu_temp = str(int(temp)/1000)
        list_temperature.append(gpu_temp)"""
        f.write_csv(list_temperature)
        time.sleep(0.5)


#-------------------------------------------thread_csv.py end------------------------------------------

def chmod():
    #sudo_password = 'nvidia'
    sudo_password = 'jetbot'
    command = 'sudo chmod 777 benchmark_jetson'
    command = command.split()

    cmd1 = subprocess.Popen(['echo',sudo_password], stdout=subprocess.PIPE)
    cmd2 = subprocess.Popen(['sudo','-S'] + command, stdin=cmd1.stdout, stdout=subprocess.PIPE)
    #output = cmd2.stdout.read().decode()
    #print('output: %s'%(output))

def get_device_capability():
    content = os.popen('./device_cap').read()
    content = content.split('\n')
    s = ''
    for item in content:
        s += item
    return s

def benchmark2():
    #cmd ='nvcc hgemm.cu -lcublas --std=c++11 -arch=sm_53  -o benchmark_nx'
    runtime = 300#测试程序运行的秒数
    times = 6#矩阵的倍数，如果是6,则矩阵的大小为6*1024
    if(len(sys.argv) > 1):
        myargus = sys.argv
        runtime = int(3600 * float(myargus[1]))
    if(len(sys.argv) > 2):
        myargus = sys.argv
        times = int(myargus[2])

    command = 'cat /etc/nv_tegra_release'
    command = command.split()
    cmd2 = subprocess.Popen( command, stdout=subprocess.PIPE)
    device_type_str = cmd2.stdout.read()
    device_type_str = str(device_type_str)
    #t210---nano---53,t186----nx---72,---agx---72,----tx1--53,tx2---62,---tx2-nx---62
    cmd = './benchmark_jetson ' + str(runtime) + ' ' + str(times)
    print('设置的总运行时间(分钟): ',runtime/60)
    result = os.system(cmd)
    return 0

def compile_create(cap):
    #t210---nano---53,t186----nx---72,---agx---72,----tx1--53,tx2---62,---tx2-nx---62
    filename = 'benchmark_jetson'
    #if(len(sys.argv) > 2):
    #    myargus = sys.argv
    #    filename = myargus[2]
    print('编译生成的文件名: ', filename)

    cmd ='nvcc hgemm.cu -lcublas --std=c++11 -arch=sm_' + cap + '  -o ' + filename
    result = os.system(cmd)
    return 0


def clear_record():
    cmd = 0 

#chmod()
#-------------thread begin------------------------
t = threading.Thread(target=getInfo4)
t.setDaemon(True)
t.start()

cap = get_device_capability()
#cap = '53'
#print(cap)
compile_create(cap)
benchmark2()

#-------------thread stop-------------------------
stop_thread(t)


