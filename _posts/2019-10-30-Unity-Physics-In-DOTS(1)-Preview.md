---
layout: post
title:  "Unity Physics In DOTS (1) - Preview"
categories:
      - Unity
tags:
    - Unity Physics
    - DOTS
excerpt: "粗略总结一下Unity2019的新物理系统 ,基于DOTS 的 Unity Physics"
image:
  path: /images/blog002/000.png
  thumbnail: /images/blog002/000.png
---

# Unity Physics In DOTS (1) - Overview
{% include toc %}
---
## 概述
在Unity 2019的版本中，Unity 推出了新的物理系统，属于DOTS中的一员，是基于Unity的HPC#/Burst实现的无状态（Stateless）物理系统。

DOTS 为了适应众多的游戏类型，需要
- 为各种网络设计做好准备
- 跨设备间的结果一致性
- 从非常小型到超级大型
Unity 和 Havok（在高性能游戏物理方面有着丰富经验的团队） 进行合作，一起开发一个无状态的物理引擎，用户可以基于自己的需求来采取这个不同的物理解决方案
- Unity Physics
  - 无状态（Stateless）
  - 适应众多的主流游戏类型
- Havok Physics
  - 缓存(Chaching)
  - 稳定和高效的模拟

---

## Authoring Data & Run-Time Data 概念

使用Unity的DOTS时，为了不影响平时在编辑器中的各种，把环境分为创作环境和运行环境，但运行游戏时，会把编辑环境中的数据全部转换为ECS中的数据。

![image-center]({{ '/images/blog002/003.png' | absolute_url }}){: .align-center}
![image-center]({{ '/images/blog002/002.png' | absolute_url }}){: .align-center}
>
Unity 的Physics Shape 和 Physics Body （分别相当于旧版本的Box Collider之类的和 Rigid Body）在run-time中会被转换为下面的组件

**运行时 Unity Physics 的主要组件**
```  
  - PhysicsCollider
  - PhysicsVelocity（速度）
  - PhysicsMass (质量，惯性，重心)
  - PhysicsDamping （阻力）
  - PhysicsGravityFactor （重力）
  - PhysicsCustomTags
```

**运行时 Unity Physics 的主要系统**
```
  - BuildPhysicsWorld
    - PhysicsWorld(CollisionWorld,DyanmicsWorld)
    - FinalJobHandle
  - StepPhysicsWorld
    - SimulationCallbacks
    - FinalJobHandle
  - ExportPhysicsWorld
    - FinalJobHandle
  - EndFramePhysicsSystem
    - HandlesToWaitFor
```
**在BuildPhysicsWorld 系统中会查询哪些Entities**
```
    1. Dynamic Entities
      - ALL:PhysicsVelocity + Translation + Rotation
    2. Static Entities
      - ALL:PhysicsCollider + Translation + Rotation
      - None:PhysicsVelocity
    3. Joint Group
      - ALL:PhysicsJoint

    静态物体与动态物体的主要区别是 ：是否有PhysicsVelocity组件
    Joint 是一种描述：用来表示两个实体间受何种约束
```
**更多高级的东西**
>
通过实现这些接口注入Unity 物理引擎的处理流程来实现自定义的效果
（具体怎么做还不了解，目前只需要知道有可以自定义的方法就好，等到需要再深入研究）

![image-center]({{ '/images/blog002/001.png' | absolute_url }}){: .align-center}

## Unity Physics 的使用

重力系数，自定义惯性空间，自定义标签
![image-center]({{ '/images/blog002/004.png' | absolute_url }}){: .align-center}

形状类型，原始方向偏移，碰撞过滤器
![image-center]({{ '/images/blog002/005.png' | absolute_url }}){: .align-center}

**这些编辑环境中MonoBehaviour组件在运行时会转换成什么**
![image-center]({{ '/images/blog002/006.png' | absolute_url }}){: .align-center}

如果子物体上都有PhysicsShapeAuthoring组件，且父物体有PhysicsBodyAuthor或者StaticOptimizeEntity组件，则Unity会把他们组合成单个复合形状的PhysicsCollider来进行优化
![image-center]({{ '/images/blog002/007.png' | absolute_url }}){: .align-center}

这篇文章是对[Overview of physics in DOTS - Unite Copenhagen](https://www.youtube.com/watch?v=tI9QfqQ9ATA&t=2s)的简单概括记录。
因为Unity Physics 还处于预览阶段，所以，上面的组件名称可能会发生变化，例如我在使用的过程中就发现`PhysicsBodyAuthoring`和`PhysicsShapeAuthoring`都已经去掉后面的`Authoring`了。
接下来会根据具体实例来熟悉一下新的物理系统
