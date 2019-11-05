---
layout: post
title: 'Ai Plan (06) 再议 Forward Search'
excerpt: "经过前面的基础知识的铺垫，再次回过头来看看，如何结合规划与搜索方法"
image:
  path: /images/blog003/ai-poster.jpg
  thumbnail: /images/blog003/ai-poster.jpg
categories:
      - 学习笔记
tags:
  - Ai
  - 学习笔记
last_modified_at: 2019-11-06T00:35:00-06:00
---
* 目录
{:toc #markdown-toc}

---
## 状态空间搜索
前面介绍过各种各样的搜索算法（广度搜索，深度搜索，A*等等），那么怎么把它们应用到规划问题中呢？
我们可以做以下转换
- 搜索空间 对应 状态空间 的子集
- 节点 对应 世界状态
- 弧（连线） 对应 状态过渡
- 路径 对应 计划方案

如何把一个规划问题定义为搜索问题。
**P = (O,s<sub>i</sub>,g)**
- 初始状态:s<sub>i</sub>
- 最终目标的满足检测: 如果当前s 满足 g时，说明找到终点
- 路径成本函数: `π = |π|` ，等于路径的长度
- 状态s后继节点函数 :  Γ(s)  
>注：Γ 是 γ的大写 ，读作"伽马"

后继节点函数Γ(s)  是用来获取当前节点的可达节点
对于定义域 **∑ = (S,A,γ)**
- S为所有状态点集
- A为所有行动的集合
- γ为过渡系统，其定义了所有状态的过渡映射
  - 即，s' = γ(s,a), 在s状态，应用动作a，可以得到状态s'

则对于Γ(s)
- 当s ∈ S时， `Γ(s) = { γ(s,a) | a ∈ A 且 a 在 s 中可用 }`
- 对于多个状态 s<sub>1</sub>,...,s<sub>n</sub> ∈ S 时,假设我们处于一组状态的某一个，当我们想要定义我们可以抵达哪些节点，即有哪些后继节点时
  - Γ( {s<sub>1</sub>,...,s<sub>n</sub>} ) = ∪<sub>k∈[1,n]</sub>Γ(S<sub>k</sub>)
    - 计算出每一个状态的Γ(s),然后将他们合并，得到一个结果集。无论输入那些状态中的任意一个状态，都可以一步取得所有可达后继节点。
  - 为使得这个定义更加通用一些，通过定义我们规定的步数，来限定结果集。意义是，**某一组状态，通过m步，可以抵达另一组状态**。
    - Γ<sup>0</sup>( {s<sub>1</sub>,...,s<sub>n</sub>} ) = {s<sub>1</sub>,...,s<sub>n</sub>}
      - 当步数为0时，我们哪也去不了，只能留在原地
    - Γ<sup>m</sup>( {s<sub>1</sub>,...,s<sub>n</sub>} ) =Γ ( Γ<sup>m-1</sup>( {s<sub>1</sub>,...,s<sub>n</sub>}))
      - 当步数为m时，通过递归这些结果集得到最终结果集的合并。

>例子
> ![image-center]({{ '/images/blog008/002.png' | absolute_url }}){: .align-center}
>如图，已知一组 {s1,s3},已知SN为其中一个，求2步后，可能抵达哪些节点
s1 一步可以抵达的点 = Γ<sup>1</sup>(s<sub>1</sub>) = {s<sub>2</sub>,s<sub>3</sub>}
s1 两步可以抵达的点 = Γ( Γ<sup>1</sup>(s<sub>1</sub>)) = Γ({s<sub>2</sub>,s<sub>3</sub>}) = {s4,s5,s6}
>
>s3 一步可以抵达的点 = Γ<sup>1</sup>(s<sub>3</sub>) = {s<sub>1</sub>,s<sub>5</sub>,s<sub>4</sub>}
s3 两步可以抵达的点 = Γ( Γ<sup>1</sup>(s<sub>3</sub>))= Γ({s<sub>1</sub>,s<sub>5</sub>,s<sub>4</sub>}）= {s<sub>2</sub>,s<sub>8</sub>,s<sub>7</sub>}
>
>最后合并两个结果 Γ<sup>2</sup>({s1,s2}) = {s4,s5,s6} ∪ {s<sub>2</sub>,s<sub>8</sub>,s<sub>7</sub>} = {s<sub>2</sub>,s<sub>5</sub>,s<sub>6</sub>,s<sub>7</sub>,s<sub>8</sub>}

最后，过渡闭路则定义:

从初始状态开始，可以抵达的所有状态
**Γ<sup>></sup>(s) =  ∪<sub>(k∈[1,∞])</sub>Γ<sup>k</sup>({s}) = Γ<sup>0</sup>(s) ∪ Γ<sup>1</sup>(s) ∪ Γ<sup>2</sup>(s) ∪ ...  ∪ Γ<sup>k</sup>(s)**

有了上面的定义，我们就可以简单的说明 一个规划问题什么情况下才会有解决方案！
>定义：一个规划问题 P = (∑,s<sub>i</sub>,g) (或者 P = (O,s<sub>i</sub>,g),∑ 是状态过渡系统，O 是操作集),当且仅当 S<sub>g</sub> ∩ Γ<sup>></sup>(s<sub>i</sub>) ≠ {} 时才存在解决方案。
即，对于所有目标的集合，与 初始节点的可抵达节点集合 的交易 一定不为空集

## 前向状态空间搜索算法（Forward State-Space Search）

```
function fwdSearch( O, s_i,g)
  state <- s_i
  plan <- <>
  loop
    if state.satisfies(g) then return plan
    applicables <- { ground instances from O applicable in state }
    if applicables.isEmpty() then return failure
    action <- applicables.chooseOne()
    state <- γ(state , action)
    plan <- plan · <action>

```
这里和我们之前提到的广度搜索方法（ Breadth First Seardh ）差不多
这里需要注意的是applicables.chooseOne()，这里我们需要使用一些技巧来进行回溯，即applicables这个东东，它是一个存储下一个操作目标的容器，或者我们自己使用其他技术实现的优先队列（如FIFO,Dijstra，启发式等等）
