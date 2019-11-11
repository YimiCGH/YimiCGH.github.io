---
layout: post
title: '关于算法算法复杂度中的P,NP,NPC'
excerpt: "记录一下算法复杂度的一些概念"
categories:
    - 学习笔记
tags:
  - 算法
  - 学习笔记
last_modified_at: 2019-11-08T06:30:00-05:00
---
{% include toc %}
---
## P 和 NP

这里的P是指多项式（polynomial）
- P问题即在多项式时间内可以找出解的决策性问题（decision problem）集合
   - 多项式，由常数和变量的乘积之和组成的表达式
      - f(n) = a*n + c
      - f(n) = a * n ^2 +b * n + c
      - f(n,m) = n * m + c
   - 非多项式：指数函数
      - f(n) = a^n
    - 多项式时间内解决
      - O(n),此描述忽略倍数，如Dijkstra 算法，节点数n和弧的数量m，O(mn)，可以在多项式时间内解决
      - O(2^n),解决问题所需时间指数递增
        - 如果n比较小，则问题求解时间可能多项式时间还少
        - 如果n比较大，则计算时间可能不同
- NP问题（non-deterministic polynomial）是在多项式时间内可以被验证其正确性的问题。**这里的N是指时间的非确定性，而不是 非多项式**

## NP-hard 和 NP-complete
**NP困难**（NP-hardness,non-deterministic polynomial-time hardness）
   - 因为Np困难问题未必可以在多项式时间内验证一个解的正确性（即不一定是NP问题）

**NP Complete** （NP 完全，缩写为NP-c或NPC），是NP中最困难的问题
- 归约：如果问题A可以用问题B的解法解决,则问题A可以规约为（“变成”）问题B，且B的复杂度>= A。如加法和乘法，加法可以使用乘法去解决, 5 + 5 + 5 =>3 * 5
  - 归约具有传递性，A可以归约为B,B可以归约为C,则A可以归约为C
  - 时间复杂度增加，应用范围变广
  - 因为以上性质，是不是可以一直归约下去，找到一个能够从简单的NP问题 到 复杂的点的大NP问题都可以解决的超级NP问题。人们假设是有的，并把它称为NPC问题，即NP完全问题，只要解决了该问题那么所有NP问题都可以解决了。


<figure class="align-center">
    <img src="https://upload.wikimedia.org/wikipedia/commons/a/a0/P_np_np-complete_np-hard.svg" alt="P，NP，NP完全和NP困难问题的欧拉图" height="200" width="320" />
   <figcaption>P，NP，NP完全和NP困难问题的欧拉图。
   在P≠NP的​​假设下，Ladner建立了NP内部但在P和NP-complete之外都存在的问题。</figcaption>
</figure>


## 图灵机
图灵机的基本思想是用机器来模拟人用笔纸进行数学运算的过程
确定性图灵机：对于确定的（程序已知的），相同的输入，可以得到相同的输出。
非确定性图灵机：对于确定的（程序已知的），相同的输入，不一定得到相同的输出。
因此，使用不确定图灵机，意味着可以使用有效的状态转移算法进行求解，
如，从当前状态S到下一个状态有N个分支，分支深度为N
- 确定性图灵机的情况下，计算量N^H
- 非确定性图灵机的情况下，由于状态转移至有效的解决方案，计算量为H，这种情况下，因为着不确定性图灵机可以在多项式时间内求解。

---
参考

[NP 复杂度- 维基百科](https://zh.wikipedia.org/wiki/NP_(%E8%A4%87%E9%9B%9C%E5%BA%A6))

[NP Complete](https://zh.wikipedia.org/wiki/NP%E5%AE%8C%E5%85%A8)

[什么是P问题、NP问题和NPC问题](http://www.matrix67.com/blog/archives/105)

[初心者が学ぶP,NP,NP困難(Hard),NP完全(Complete)とは（わかりやすく解説）](http://motojapan.hateblo.jp/entry/2017/11/15/082738)
