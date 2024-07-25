#!env python
#########################################################################
# File Name: 9.autoGuiOpt.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年09月12日 星期二 23时05分45秒
#########################################################################

try:
    import time
    import datetime
    import schedule
    import pyautogui
except Exception as err_info:
    print(err_info)
    exit(0)

def dumpInfo():
    print("{} ==> gui info:".format(datetime.datetime.now()))
    print("--> screen size")
    # Get the size of the primary monitor.
    screenWidth, screenHeight = pyautogui.size()
    print("screen size: (%d, %d)" % (screenWidth, screenHeight))

    print("--> cur mouse loc")
    # Get the XY position of the mouse.
    currentMouseX, currentMouseY = pyautogui.position()
    print("mouse loc: (%d, %d)" % (currentMouseX, currentMouseY))
    print()

# 定义你要周期运行的函数
def printerCheck():
    print("{} ==> printer check begin...".format(datetime.datetime.now()))
    print("--> move to button and click button")
    time.sleep(1)
    # Find where button.png appears on the screen and click it.
    try:
        pyautogui.click('print.png')
    except Exception as err_info:
        print("errinfo:")
        print(err_info)
        print("maybe connot find button")
    print("==> printer check finish")
    print()

def printerClean():
    print("{} ==> printer clean begin...".format(datetime.datetime.now()))
    print("--> move to button and click button")
    time.sleep(1)
    # Find where button.png appears on the screen and click it.
    try:
        pyautogui.click('cleaning.png')
        time.sleep(1)
        pyautogui.click('ok.png')
        time.sleep(1)
        pyautogui.click('ok.png')
        time.sleep(15)
        pyautogui.click('ok.png')
    except Exception as err_info:
        print("errinfo:")
        print(err_info)
        print("maybe connot find button")
    print("==> printer clean finish")
    print()

if __name__ == '__main__':
    # 调用scedule.every(间隔).时间类型.do(job) 发布周期任务
    # 发布后的周期任务需要用run_pending函数来检测是否执行，因此需要一个While循环不断地轮询这个函数。

    # 按时间间隔执行
    # schedule.every().second.do(job)
    #-- schedule.every(1).second.do(printerCheck)
    #-- schedule.every(1).second.do(printerClean)
    # schedule.every(1).minutes.do(printerCheck)               # 每隔 1 分钟运行一次
    # schedule.every(1).minutes.do(printerClean)               # 每隔 1 分钟运行一次
    # schedule.every().hour.do(job)                    # 每隔 1 小时运行一次 job 函数

    # 按时间周期执行
    # schedule.every().minute.at(":17").do(job)        # 每分钟的 17 秒时间点运行 job 函数
    # schedule.every().day.at("10:30").do(job)         # 每天在 10:30 时间点运行 job 函数
    schedule.every().tuesday.at("20:00").do(printerCheck)       # 每周二 20:00 时间点运行
    schedule.every().saturday.at("20:00").do(printerCheck)      # 每周六 20:00 时间点运行
    schedule.every().saturday.at("20:30").do(printerClean)      # 每周六 20:30 时间点运行

    # 在指定时间停止
    # schedule.every(1).hours.until("18:30").do(job)                                     # 每个小时运行作业，18:30后停止
    # schedule.every(1).hours.until("2030-01-01 18:33").do(job)                          # 每个小时运行作业，2030-01-01 18:33 today
    # schedule.every(1).hours.until(datetime.timedelta(hours=8)).do(job)                 # 每个小时运行作业，8个小时后停止
    # schedule.every(1).hours.until(datetime.time(23, 33, 42)).do(job)                   # 每个小时运行作业，23:32:42后停止
    # schedule.every(1).hours.until(datetime.datetime(2024, 5, 17, 11, 36, 20)).do(job)  # 每个小时运行作业，2024-5-17 11:36:20后停止

    # # .tag 打标签
    # schedule.every().day.do(greet, 'Andrea').tag('daily-tasks', 'friend')
    # schedule.every().hour.do(greet, 'John').tag('hourly-tasks', 'friend')
    # schedule.every().hour.do(greet, 'Monica').tag('hourly-tasks', 'customer')
    # schedule.every().day.do(greet, 'Derek').tag('daily-tasks', 'guest')
    # # get_jobs(标签)：可以获取所有该标签的任务
    # friends = schedule.get_jobs('friend')
    # # 取消所有 daily-tasks 标签的任务
    # schedule.clear('daily-tasks')

    # 如果某个机制触发了，你需要立即运行所有作业，可以调用schedule.run_all():
    # schedule.run_all()
    # 立即运行所有作业，每次作业间隔10秒
    # schedule.run_all(delay_seconds=10)
    all_jobs = schedule.get_jobs()
    for job_tmp in all_jobs:
        print(job_tmp)

    dumpInfo()

    # schedule其实就只是个定时器。在while True死循环中，schedule.run_pending()是保持schedule一直运行，去查询上面那一堆的任务
    while True:
        schedule.run_pending()   # 运行所有可以运行的任务
        time.sleep(1)
