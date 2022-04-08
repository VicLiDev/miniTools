#!/system/bin/sh
# 循环播放器列表中的视频，一直切换下一个视频
############### main #####################
j=1
jmax=20000000
sleep 6

am start -n android.rk.RockVideoPlayer/.RockVideoPlayer
sleep 2
input keyevent 20
sleep 1
input keyevent 23
sleep 1

while [ $j -lt $jmax ];
do
	echo "again count:$j"
	j=$((j+1))
	input keyevent 87
	sleep 1
	
done
