#!/usr/bin/env python

import os
import sys
import subprocess

import threading
import time
#from IPython.display import clear_output
import ctypes
import inspect


def get_device_capability():
    command = 'sudo chmod 777 device_cap'
    command = command.split()
    if(len(sys.argv) > 1):
        myargus = sys.argv
        sudo_password = myargus[1]

    cmd1 = subprocess.Popen(['echo',sudo_password], stdout=subprocess.PIPE)
    cmd2 = subprocess.Popen(['sudo','-S'] + command, stdin=cmd1.stdout, stdout=subprocess.PIPE)
    time.sleep(1)
    content = os.popen('./device_cap').read()
    content = content.split('\n')
    s = ''
    for item in content:
        s += item
    return s

def compile_create(cap):
    #t210---nano---53,t186----nx---72,---agx---72,----tx1--53,tx2---62,---tx2-nx---62
    filename = 'benchmark_jetson'
    if(len(sys.argv) > 2):
        myargus = sys.argv
        filename = myargus[2]
    print('filename: ', filename)

    cmd ='nvcc hgemm.cu -lcublas --std=c++11 -arch=sm_' + cap + '  -o ' + filename
    result = os.system(cmd)
    return 0

cap = get_device_capability()
#cap = '53'
print(cap)

compile_create(cap)

