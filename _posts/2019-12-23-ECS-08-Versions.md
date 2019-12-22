---
layout: post
title: 'Unity ECS 研究 08 —— 版本'
categories:
      - 翻译
tags:
  - ECS
  - Unity
last_modified_at: 2019-12-22T23:00:00-23:00
---
{% include toc %}
---
## 版本号
版本号（又称世代），其目的是检测潜在的更改。除此之外，它们还可用于实施廉价且有效的优化策略，例如：保证自上一帧以来未更改其操作的数据时，可能会跳过某些处理。

通过一次性对一组实体执行非常快速的保守的（低于实际数量的）版本检查，常常可以轻松获得显着的性能提升。

此页面列出并记录了ECS使用的所有不同版本号，特别是会导致它们更改的特殊情况。

## 初步说明
所有版本号都是32位带符号整数，除非它们回绕，否则它们始终会增加（带符号整数溢出是C＃中定义的行为）。这意味着比较版本号应该使用（不相等）运算符而不是关系运算符进行。

检查VersionB是否比VersionA更加新的正确方法是：bool VersionBIsMoreRecent =（VersionB-VersionA）> 0;
通常无法保证版本号会增加多少。

## EntityId.Version
EntityId由索引和版本号组成。由于索引被回收，因此每次破坏实体时，EntityManager中的版本号都会增加。如果在EntityManager中查询EntityId时版本号不匹配，则意味着所引用的实体已不存在。

>在通过EntityId获取某个单位正在跟踪的敌人的位置之前，您可以调用ComponentDataFromEntity.Exists，它使用版本号检查该实体是否仍然存在。

## World.Version
每当创建或销毁管理器（即系统）时，world的版本号都会增加。

## EntityDataManager.GlobalVersion
在每个`（Job）ComponentSystem`更新之前增加。
>此版本号的目的是与System.LastSystemVersion一起使用。

## System.LastSystemVersion
在每个`（Job）ComponentSystem`更新后，获取`EntityDataManager.GlobalVersion`的值。
>此版本号的目的是与Chunk.ChangeVersion []结合使用。

## Chunk.ChangeVersion
对于原型中的每种组件类型，此数组均包含该组件中最后一次以可写状态访问组件数组时EntityDataManager.GlobalVersion的值。无法确保任何事物都已经有效地改变了，仅保证它可能已经改变了。

共享组件永远无法以可写方式访问它们，即使在技术上也为共享组件存储了版本号。

在`IJobForEach`中使用`[ChangedFilter]`属性时，会将特定组件的`Chunk.ChangeVersion`与`System.LastSystemVersion`进行比较，因此仅处理其组件数组自系统上次开始运行以来已被可写访问的块。

>例如，如果保证自上一帧以来一组单位的生命值未发生变化，则可以完全跳过检查那些单位是否应更新其损坏模型的检查。

## EntityManager.m_ComponentTypeOrderVersion[]
对于任何非共享组件类型，每次涉及该类型的迭代器应该无效时，都会增加版本号。换句话说，任何东西都可能修改该类型的数组（不是实例）。
>如果我们有一个特定的组件，来标识静态对象，以及每个块的边界框，那么我们知道，如果该组件的类型顺序版本发生更改，我们只需要更新这些边界框即可。

## SharedComponentDataManager.m_SharedComponentVersion[]
当存储在引用该共享组件的块中的实体发生任何结构更改时，这些版本号会增加。

>想象一下，我们为每个共享组件保留了一个实体计数，如果相应的版本号发生更改，我们可以依靠该版本号仅重做每个计数。
