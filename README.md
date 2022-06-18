# jetson_benchmark

作者:shihailong

邮箱:lengkujiaai@126.com

----记于2021-11-30

开发前的大体设想：
1、	可以运行在nano、nx、agx、tx2-nx上面，一直跑，调动gpu

2、	计算matrixA、matrixB，使gpu跑起来

3、	可以记录温度、电流、功耗、性能，，gpu占有率，每秒一次

4、	写到一个run.sh，在不同平台自动选择，命令行执行或者双击

5、	将中间结果存入txt日志或csv中

6、	考虑到存储占用空间，按最多跑10天设计，，中文显示


目前状态：没有电流、gpu占有率

其中用到了几个参考：

1、	cublasHgemm-P100，，，这个是agx的/usr/local/cuda-10.0/samples下面的示例，可以跑32位或16位的矩阵乘法，测量gpu性能，，，，，对其进行了修改，将16位和32位的计算性能写入csv文件

2、	deviceQuery,,, /usr/local/cuda-10.0/samples/1_Utilities下面，可以查看设备信息，方便根据不同设备进行编译，，，进行了编辑，生成可执行文件device_cap，后面调用

3、	jetbot
      https://github.com/lengkujiaai/jetbot
      可以调用设备温度、电压，，可以拿到cpu、gpu的温度，功耗，并将这些测试信息计入csv文件

文件放在jetson_stats/benchmark_cuda目录下面，主要包含的文件有：

device_cap , hgemm.cu , fp16_conversion.h , csv_file.py , python_exe.py ，

测试用文件有arguspy , time.cu , thread_csv.py , nano_16_32_cuda , a 

编译生成文件有 benchmark_shi

用到的知识点：

1、	python命令行参数，用来获取用户要运行的时间，用户输入的是小时，可以是0.01也可以是15或78，，，，c语言的命令行参数，python调用可执行文件时把运行时间按秒数的整数形式传过去

2、	开启线程A，运行对jetbot的修改，保存cpu、gpu温度、功耗信息，见截图1

![image](https://github.com/lengkujiaai/jetson_benchmark/tree/main/image/1.png)


3、	调用可执行文件device_cap，获取设备的计算能力，比如nano是5.3，得到的返回值为53，，tx2和tx2-nx的计算能力为6.2，返回值为62，，agx的计算能力为7.2，返回值为72，，，返回的没有小数点是因为方便后面编译cuda文件使用。在函数benchmark2中对hgemm.cu进行编译，，，生成可执行文件 benchmark_shi，，运行benchmark_shi，结束后，结束线程A的运行

4、	在hgemm.cu中添加一些改动：

把gpu运行的性能及时间信息保存到csv中，，32位16位交替运行，都记录，，csv第一行记录名称：统计、性能（GFlop/s）、耗时，见截图2

![image](https://github.com/lengkujiaai/jetson_benchmark/tree/main/image/2.png)


添加获取系统时间的函数及变量

通过命令行参数获取运行时间，时间到了，自动跳出循环，关闭对csv的保存。没有运行完退出，不会保存会导致读取失败

5、	增加计算过程中对实时温度、功耗、性能的打印，见截图3

![image](https://github.com/lengkujiaai/jetson_benchmark/tree/main/image/3.png)
