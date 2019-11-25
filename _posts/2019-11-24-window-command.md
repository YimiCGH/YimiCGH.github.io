---
layout: post
title: 'Window cmd 常用指令'
categories:
      - 学习笔记
tags:
  - window
last_modified_at: 2019-11-24T5:30:00-21:00
---
{% include toc %}
---
## 新建文件夹和文件
|命令|说明|
|-|-|
|cd .. |          返回上一级|
|md test   |      新建test文件夹|
|md d:\test\my |  d盘下新建文件夹|
|cd test       |   进入test文件夹|
|cd.>cc.txt    |  新建cc.txt文件|
|dir           |  列出文件夹下所有文件及文件夹|


## 删除文件夹和文件
|命令|说明|
|---|-|
|cd test  |       进入test文件夹|
|dir       |      查看所有文件目录|
|del a.txt  |     删除a.txt的文件|
|del *.txt  |     删除所有后缀为.txt的文件|
|rd test    |     删除名为test的空文件夹|
|rd /s D:\test |  删除D盘里的test文件夹,会出现如下` test, 是否确认(Y/N)?`,直接输入Y然后回车|
|rd test/s  |   删除此文件夹下的所有文件`test, 是否确认(Y/N)?`直接输入Y 然后回车|

>注意 del 是用来删除文件，rd 是用来删除文件夹，/s是用来做防止误删，做二次确认

## 其它
|---|-|
|cls  | 清屏|

————————————————
参考
- [cmd新建、删除文件和文件夹](https://blog.csdn.net/super__code/article/details/79613035)
