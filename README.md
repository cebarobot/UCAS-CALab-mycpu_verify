# UCAS Computer Architecture Lab (Lab 3 ~ Lab 9)
> Powered by ceba & ywk

此仓库内容配合 `CPU_CDE` 实验环境使用，对应 `CPU_CDE\mycpu_verify`。

RTL 代码位于 `rtl\myCPU`，单独查看某个 Lab 的代码请查询对应的 commit 历史。

## 内容
|  Lab  | 章节       | 标题                             |
| :---: | :--------- | :------------------------------- |
| Lab3  | 第四章 7.1 | 简单 CPU 参考设计调试            |
| Lab4  | 第四章 7.2 | 阻塞技术解决相关引发的冲突       |
| lab5  | 第四章 7.3 | 前递技术解决相关引发的冲突       |
| lab6  | 第五章 4   | 在流水线中添加运算类指令         |
| lab7  | 第六章 3   | 在流水线中添加转移指令和访存指令 |
| lab8  | 第七章 4.1 | 添加 syscall 例外支持            |
| lab9  | 第七章 4.2 | 添加其它例外支持                 |

## 使用方法
* Clone 仓库
* 用 Vivado 打开项目文件 `run_vivado\mycpu_prj1\mycpu_prj1.xpr`
* 重新生成 IP 核的输出产品（Reset & Generate Output Products）
* 根据讲义内容，尝试进行仿真、综合。
