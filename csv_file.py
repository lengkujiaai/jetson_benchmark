from datetime import datetime
import time
import os
import csv
import shutil


"""
author:shi

0 need to call init_time_relates() every time or every day

1  remember to call mkdir() because it will change from day to day ,month to month, year to year

2 there will create new year and month dir(if not exists) and day csvFile at midnight

"""


class CsvFile:
    def __init__(self,save_dir='record_temperature/',max_store=3221225472,first_row=['id1','id2','id3','id4','id5']):
        self.save_dir = save_dir
        self.max_store = max_store#size:3G 
        self.max_year = 5000 #suppose it will be used from the year of 2020 to 5000
        self.first_row = first_row
        self.csv_create_time = [23,0,0,5]#0-ready time,1-hour,2-minute,3-seconds to create
        self.if_csv_created = False #make sure everyday only create one csv file
        
        #self.csv_create_time = [23,10,2,10] #for test
        
        self.init_time_relates()
        self.mkdir()
        self.create_csv()

    def init_time_relates(self):
        year_directory_filename = self.save_dir + time.strftime("%Y")
        month_directory_filename = time.strftime("%m")
        day_Filename = time.strftime("%d") + '.csv'
        self.y = year_directory_filename
        self.m = self.y + '/' + month_directory_filename
        self.d = self.m + '/' + day_Filename

    def time_to_create_csv(self):#init time relates,create csv file and create directory
        csv_create_time = self.csv_create_time
        h = datetime.now().hour
        m = datetime.now().minute
        s = datetime.now().second
        if h == csv_create_time[0]:
            self.if_csv_created = False
            #print('ready to create csv file')
        if self.if_csv_created == False:
            if h==csv_create_time[1] and m==csv_create_time[2] and s<csv_create_time[3]:
                print('I am creating csv file')
                self.compare_size()
                self.init_time_relates()
                self.mkdir()
                self.create_csv()
                self.if_csv_created = True
                return 1
        else:
            return 0
    
    def mkdir(self):#create directory year and month
        isExists = os.path.exists(self.y)
        if not isExists:
            os.makedirs(self.y)
        isExists = os.path.exists(self.m)
        if not isExists:
            os.makedirs(self.m)
            #print('--make dir ok:',self.m)

    def create_csv(self):
        csvFile = open(self.d, 'w',newline='')
        try:
            writer = csv.writer(csvFile)
            writer.writerow((self.first_row))
        finally:
            csvFile.close()

    def write_csv(self,cList):
        csvFile = open(self.d, 'a+')
        try:
            writer = csv.writer(csvFile)
            writer.writerow(cList)
        finally:
            csvFile.close()

    def get_file_size(self,filePath, size=0):#size: bytes
        for root,dirs,files in os.walk(filePath):
            for f in files:
                size += os.path.getsize(os.path.join(root, f))
        return size

    def compare_size(self):
        p = self.save_dir
        size = 0
        min_dir_name = ''
        min_dir_size = self.max_year
        dir_list = os.listdir(p)
        for item in dir_list:
            s = self.get_file_size(p+item)
            size += s
            if int(item) < min_dir_size:
                min_dir_name = item
                min_dir_size = int(item)
        if size > self.max_store:
            shutil.rmtree(p + min_dir_name)

if __name__ == '__main__':
    save_dir = '/home/record_temperature/'
    max_store = 2520000
    f = CsvFile(save_dir,max_store)
    i = 1
    
    while True:
        f.time_to_create_csv()
        i +=1
        if i ==10:
            break
        l = ['dajiahao','wohao','nihao']
        f.write_csv(l)
    #f.compare_size()



