使用方法：
1. 执行将需要测试的片源，写入 in_eval_info.txt
2. 执行 sw_codec.sh，输入选择 enable 的 core 和希望设置的 core 频率
3. 执行结束之后，会重新要求输入选择 enalbe 的 core 和希望设置的 core 频率，
   因为可能需要测试单核多核之类的场景
4. 当完成所需的测试之后，输入 q 退出 sw_codec.sh
5. 测试得到的数据，会被存放在 eval_data_bakup 文件夹中，并复制一份到
   out_eval_data.txt 用于生成 excel 文件
6. 执行 gen_doc.py，它会读取 out_eval_data.txt 文件，并生成一份excel文档

tips:
有时候需要在pc上先简单跑一下测试，可以取消注释 sw_codec.sh 文件中，main函数中的行：
`# use_dev="false"`
