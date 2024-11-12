/*************************************************************************
    > File Name: test.c
    > Author: LiHongjin
    > Mail: 872648180@qq.com
    > Created Time: Tue 12 Nov 2024 02:29:53 PM CST
 ************************************************************************/

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <sched.h>
#include <string.h>

#define DEFAULT_THREAD_COUNT 4
#define SLEEP_DURATION 1 // 线程休眠时间（微秒）

// 线程执行的计算任务（降低了计算密度）
void *thread_task(void *arg)
{
    int thread_id = *(int *)arg;

    // 设置线程名字
    char thread_name[16];
    snprintf(thread_name, sizeof(thread_name), "Worker-%d", thread_id);
    pthread_setname_np(pthread_self(), thread_name);

    // 获取并打印线程名字
    char name[16];
    pthread_getname_np(pthread_self(), name, sizeof(name));
    printf("Thread %d started with name: %s\n", thread_id, name);

    // 无限循环进行简单计算，并加入休眠
    double x = 0.1;
    while (1) {
        // 获取当前线程运行的 CPU 编号
        int cpu = sched_getcpu();
        printf("Thread %s(id:%ld) is running on CPU %d\n", name, pthread_self(), cpu);

        // 简单计算
        x = x * x + 0.5;
        if (x > 1000.0) {
            x = 0.1;
        }

        // 休眠，降低 CPU 占用率
        usleep(SLEEP_DURATION);
    }

    return NULL;
}

int main(int argc, char *argv[])
{
    int thread_count = DEFAULT_THREAD_COUNT;
    if (argc > 1) {
        thread_count = atoi(argv[1]);
        if (thread_count <= 0) {
            fprintf(stderr, "Invalid thread count. Using default: %d\n",
                    DEFAULT_THREAD_COUNT);
            thread_count = DEFAULT_THREAD_COUNT;
        }
    }

    pthread_t threads[thread_count];
    int thread_ids[thread_count];

    // 打印主线程的 CPU 编号
    int cpu = sched_getcpu();
    printf("Main Thread %ld is running on CPU %d\n", pthread_self(), cpu);

    printf("Starting %d threads...\n", thread_count);

    // 创建线程
    for (int i = 0; i < thread_count; i++) {
        thread_ids[i] = i;
        if (pthread_create(&threads[i], NULL, thread_task, &thread_ids[i]) != 0) {
            perror("Failed to create thread");
            return 1;
        }
    }

    // 主线程等待子线程（无限等待，程序需要手动终止）
    for (int i = 0; i < thread_count; i++) {
        pthread_join(threads[i], NULL);
    }

    return 0;
}

