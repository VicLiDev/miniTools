#!/bin/python3
#########################################################################
# File Name: 5.delayExec.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed Jun 21 15:24:19 2023
#########################################################################

# 参考： https://zhuanlan.zhihu.com/p/501021369

try:
    import schedule
    import time
    import datetime
except Exception as err_info:
    print("errinfo:")
    print(err_info)
    exit(0)


# 定义你要周期运行的函数
def job():
    print("I'm working...")

def job2():
    print("I'm working2...")

if __name__ == '__main__':
    # 调用scedule.every(间隔).时间类型.do(job) 发布周期任务
    # 发布后的周期任务需要用run_pending函数来检测是否执行，因此需要一个While循环不断地轮询这个函数。

    # 按时间间隔执行
    schedule.every().second.do(job)
    schedule.every().second.do(job2)
    # schedule.every(1).minutes.do(job)                # 每隔 1 分钟运行一次 job 函数
    # schedule.every(10).minutes.do(job)               # 每隔 10 分钟运行一次 job 函数
    # schedule.every().hour.do(job)                    # 每隔 1 小时运行一次 job 函数

    # 按时间周期执行
    # schedule.every().minute.at(":17").do(job)        # 每分钟的 17 秒时间点运行 job 函数
    # schedule.every().day.at("10:30").do(job)         # 每天在 10:30 时间点运行 job 函数
    # schedule.every().monday.do(job)                  # 每周一 运行一次 job 函数
    # schedule.every().wednesday.at("13:15").do(job)   # 每周三 13：15 时间点运行 job 函数

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

    # schedule其实就只是个定时器。在while True死循环中，schedule.run_pending()是保持schedule一直运行，去查询上面那一堆的任务
    while True:
        schedule.run_pending()   # 运行所有可以运行的任务
        time.sleep(1)
