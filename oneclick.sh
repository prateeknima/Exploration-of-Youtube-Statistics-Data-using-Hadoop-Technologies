#!/bin/bash

#Creating variable with desired paths
LOCAL_PATH='/home/prateek/Desktop/myProject'
HDFS_PATH='hdfs://localhost:54310'
HADOOP_PATH='/usr/local/hadoop'
HBASE_PATH='/usr/local/hbase'
HIVE_PATH='/usr/local/hive'
#Starting all the Hadoop Services
echo "---------------------------------------------------------------------------------------------"
echo "Starting All the Hadoop Services"
echo "----------------------------------------------------------------------------------------------"
$HADOOP_PATH/sbin/start-dfs.sh
$HADOOP_PATH/sbin/start-yarn.sh
$HBASE_PATH/bin/start-hbase.sh

#Download Data and clean it
echo "----------------------------------------------------------------------------------------------"
echo "Downloading all the required libraries and cleaning the data using R script"
echo "----------------------------------------------------------------------------------------------"
sudo chmod o+w /usr/local/lib/R/site-library
sudo apt install apt-transport-https software-properties-common
sudo add-apt-repository deb https://cloud.r-project.org/bin/linux/ubuntu bioni$
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DF$
sudo chmod o+w /usr/local/lib/R/site-library
sudo apt update
sudo apt install r-base
sudo apt-get install rstudio-server
sudo apt-get install r-cran-rjson

sudo rm -r $LOCAL_PATH/Datasets/cleaned_datasets
sudo rm -r $LOCAL_PATH/Datasets/final_data
sudo mkdir $LOCAL_PATH/Datasets/cleaned_datasets
sudo mkdir $LOCAL_PATH/Datasets/final_data
sudo chmod -R 777 $LOCAL_PATH/Datasets

Rscript $LOCAL_PATH/Clean_Data_Rfiles/clean_and_merge_kaggle.R
Rscript $LOCAL_PATH/Clean_Data_Rfiles/clean_api_data.R
Rscript $LOCAL_PATH/Clean_Data_Rfiles/create_final_dataset.R

#Load Data in mySQL
echo "---------------------------------------------------------------------------------------------"
echo "Loading the Data to MySQL"
echo "---------------------------------------------------------------------------------------------"
mysql --local-infile=1 -uroot -p < uploadData.sql

#Load Data From mySQL to HDFS
echo "---------------------------------------------------------------------------------------------"
echo "Loading Data From MySQL to HDFS using sqoop"
echo "---------------------------------------------------------------------------------------------"
sqoop import --connect jdbc:mysql://127.0.0.1/myyoutube --username root --password qwerty --table mydata --target-dir /youtubedata -m 1

#Creating the Output Directory at the local path
echo "----------------------------------------------------------------------------------------------"
echo "Deleting Output Directory if Exists and Creating and Granting Permissions to new directory"
echo "----------------------------------------------------------------------------------------------"
sudo rm -r $LOCAL_PATH/output
sudo mkdir $LOCAL_PATH/output
sudo chmod 777 $LOCAL_PATH/output

#Executing Pig Query 1
echo "-------------------------------------------------------------------------------------------"
echo "Executing Pig Query 1"
echo "--------------------------------------------------------------------------------------------"
echo -e "disable 'pigQuery1'" | hbase shell -n
echo -e "drop 'pigQuery1'"| hbase shell -n
echo "create 'pigQuery1','Id','Country','Average_Views'"|hbase shell
pig -x local $LOCAL_PATH/pigQueries/pigQuery1.pig
echo "scan 'pigQuery1'" | hbase shell > $LOCAL_PATH/output/pigQuery1.csv


#Executing Pig Query 2
echo "---------------------------------------------------------------------------------------------"
echo "Executing Pig Query 2"
echo "----------------------------------------------------------------------------------------------"
echo -e "disable 'pigQuery2'" | hbase shell -n
echo -e "drop 'pigQuery2'"| hbase shell -n

echo "create 'pigQuery2','Id','Country','Video_Count'"|hbase shell
pig -x local $LOCAL_PATH/pigQueries/pigQuery2.pig
echo "scan 'pigQuery2'" | hbase shell > $LOCAL_PATH/output/pigQuery2.csv


#Executing Java Query 1
echo "-----------------------------------------------------------------------------------------------"
echo "Executing Java Query 1"
echo "-----------------------------------------------------------------------------------------------"
echo -e "disable 'javaQuery1'" | hbase shell -n
echo -e "drop 'javaQuery1'"| hbase shell -n

$HADOOP_PATH/bin/hadoop jar $LOCAL_PATH/javaQueries/javaQuery1.jar youtubeQuery1/driver1  $HDFS_PATH/youtubedata $HDFS_PATH/javaOutput1
echo "create 'javaQuery1','Id','Value'"|hbase shell
pig -x local $LOCAL_PATH/javaToHbase_pig/java1.pig
echo "scan 'javaQuery1'"| hbase shell > $LOCAL_PATH/output/javaQuery1.csv


#Executing Java Query 2
echo "-----------------------------------------------------------------------------------------------"
echo "Executing Java Query 2"
echo "-----------------------------------------------------------------------------------------------"

echo -e "disable 'javaQuery2'" | hbase shell -n
echo -e "drop 'javaQuery2'"| hbase shell -n
$HADOOP_PATH/bin/hadoop jar $LOCAL_PATH/javaQueries/javaQuery2.jar youtubeQuery2/driver2  $HDFS_PATH/youtubedata $HDFS_PATH/javaOutput2
echo "create 'javaQuery2','Id','Value'"|hbase shell
pig -x local $LOCAL_PATH/javaToHbase_pig/java2.pig
echo "scan 'javaQuery2'"| hbase shell > $LOCAL_PATH/output/javaQuery2.csv


#Executing Java Query 3
echo "-----------------------------------------------------------------------------------------------"
echo "Java Query 3"
echo "-----------------------------------------------------------------------------------------------"
echo -e "disable 'javaQuery3'" | hbase shell -n
echo -e "drop 'javaQuery3'"| hbase shell -n


$HADOOP_PATH/bin/hadoop jar $LOCAL_PATH/javaQueries/javaQuery3.jar youtubeQuery3/driver3  $HDFS_PATH/youtubedata $HDFS_PATH/javaOutput3
echo "create 'javaQuery3','Id','Value'"|hbase shell
pig -x local $LOCAL_PATH/javaToHbase_pig/java3.pig
echo "scan 'javaQuery3'"| hbase shell > $LOCAL_PATH/output/javaQuery3.csv

#Executing Spark Query
echo "---------------------------------------------------------------------------------------------"
echo "Executing Spark Query"
echo "----------------------------------------------------------------------------------------------"
unset PYSPARK_DRIVER_PYTHON
spark-submit $LOCAL_PATH/sparkQueries/spark.py
#echo "create 'sparkQuery1','channel_title','views','country','month'"|hbase shell
#pig -x local $LOCAL_PATH/sparkToHbase_pig/spark1.pig
#echo "scan 'sparkQuery1'"| hbase shell > $LOCAL_PATH/output/sparkQuery1.csv
sudo mkdir $LOCAL_PATH/output/sparkOutput
sudo chmod -R 777 output
hadoop fs -get /user/hduser/myspark/* $LOCAL_PATH/output/sparkOutput


#Executing Hive Query
echo "---------------------------------------------------------------------------------------------"
echo "Executing Hive Query"
echo "----------------------------------------------------------------------------------------------"
echo -e "disable 'hiveQuery'" | hbase shell -n
echo -e "drop 'hiveQuery'"| hbase shell -n

$HIVE_HOME/bin/hive -f $LOCAL_PATH/hiveQueries/hiveQuery1.sql
echo "scan 'hiveQuery'"| hbase shell > $LOCAL_PATH/output/hiveQuery.csv


echo "---------------------------------------------------------------------------------------------"
echo "Execution has Completed"
echo "Please check the $LOCAL_PATH/output directory"
echo "---------------------------------------------------------------------------------------------"
