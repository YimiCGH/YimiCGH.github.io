---
layout: post
title: 'Unity ECS 研究 03 —— 组件'
categories:
      - 翻译
tags:
  - ECS
  - Unity
last_modified_at: 2019-12-18T23:00:00-23:00
---
{% include toc %}
---

组件是ECS架构中的第二个主要部分。它们表示游戏中的数据。实体实质上是索引一组组件的标识符。系统则提供行为来处理这些组件上的数据。

具体来说，在Unity中，一个ECS的组件是一个继承了下面接口（其中一个）的结构体
- IComponentData —— 用于通常使用和块组件
- IBufferElementData —— 用来访问实体上的动态缓存
- ISharedComponentData —— 用来根据原型中的值对实体进行分类或分组
- ISystemStateComponentData —— 用来将系统特定状态与实体关联，以及检测何时创建和销毁各个实体
- ISharedSystemStateComponent —— 共享数据和系统状态数据的组合
- Blob assets —— 当技术意义上不是一个“的组件”时，你可以使用Blob assets来存储数据，Blob asset 可以被一个或多个组件通过 BlobAssetReference引用，并且是不可变的。Blob Asset允许你在Assets之间共享数据并访问C# Job中的数据

EntityManager 将实体与组件之间的组合组织为原型，它将具有相同原型的所有实体的组件一起储存到一个称为块的内存块中。在一个块中的所有实体均具有相同的组件原型

<img src="https://docs.unity3d.com/Packages/com.unity.entities@0.3/manual/images/ArchetypeChunkDiagram.png" class="align-center" alt="">

上图说明了原型是如何将组件数据存储到块中。共享组件和块组件是例外，因为它们存储在块外部。由这些组件创建的实例可以适用于块中的所有实体。另外，你可以将动态缓存存储在块的外面，尽管这些组件不在块的内部，你也可以将它们当成和其他组件类型一样来对待。

## 通用组件（General purpose components）
组件是一个只包含实体的实例数据的结构体，不包含除访问结构体内数据的辅助函数以外的任何函数。所有的游戏逻辑以及行为都由对应的系统实现。

Unity ECS API 提供 `IComponentData`接口来实现自定义的组件，因为建议使用结构来继承 `IComponentData`接口，所以，我们会常常用下面这种模式来修改数据。

```CSharp
var transform = group.transform[index]; // Read

transform.heading = playerInput.move; // Modify
transform.position += deltaTime * playerInput.move * settings.playerMoveSpeed;

group.transform[index] = transform; // Write
```

IComponentData结构中应该不包含任何对托管对象的引用。由于ComponentData驻留在简单的非垃圾收集的跟踪内存块中，因此具有许多性能优势

**托管型 IComponentData**

为了帮助把现有的代码零星的移植到ECS架构，在和不适合ISharedComponentData的托管数据进行交互或在首次对数据布局进行原型设计时，，用托管型IComponentData会比较方便（即，用类而不是结构体来声明IComponentData）。

这种方式声明的组件的使用方式和值类型的IComponentData的相同，但是，在内部以非常不同（且较慢）的方式进行处理。

在不需要使用托管类IComponentData支持的用户应该在`Project Settings -> Player -> Scripting Define Symbols`中添加宏`UNITY_DISABLE_MANAGED_COMPONENTS`来防止意外使用。

从本质上来讲，与值类型的IComponentData相比，托管型IComponentData有以下缺陷
- 不能使用Burst Complier
- 不能在Job 结构体中使用
- 不能使用块内存
- 需要垃圾回收

用户应该尝试限制托管型组件的数量，并尽可能选择 (Blittable)[https://docs.microsoft.com/zh-tw/dotnet/framework/interop/blittable-and-non-blittable-types?redirectedfrom=MSDN]类型的数据（简单来说就是在托管和非托管代码之间不需要特殊处理，可以直接转换传递的类型，如int,byte；非Blittable类型如string ,object , class）

托管型 IComponentData 必须实现接口 IEquatable<T>，并重写`Object.GetHashCode()`。出于序列化的目的。托管型组件必须有默认可构造函数。

由于托管型组件本质上是不可扩展的，因此这些组件存储在每个ArchetypeChunk间接知道的由Entity索引的托管C#数组中。

你必须使用EntityManager 或EntityCommandBuffer在主线程上设置组件的值。作为引用类型，你可以直接改变组件的值，而无需像ISharedComponentData那样跨大块移动身体，因此不会创建同步点。但是，尽管逻辑上将其与值类型的组件分开存储，但是托管型组件也是实体原型的定义的一部分。因此，在向实体添加或移除托管型组件任会导致创建新的原型（如果不存在匹配的原型的话），并且将该实体移动到新的块。

相关源码可以查看`/Packages/com.unity.entities/Unity.Entities/IComponentData.cs`

## 共享组件（Shared Component Data）

共享组件是一种特殊的数据组件，可以根据共享组件中的特定值（除了原型之外）对实体进行分类。当你将共享组件添加到实体中时，EntityManager会将所有具有系统共享数据值的实体放到同一个块中。共享组件使你的系统可以像实体一样处理。如，共享组件Rendering.RenderMesh是Hybrid.rendering包的一部分，它定义了多个字段，包括网格，材质，阴影接收等。渲染时，最有效的方法是一起处理所有对于这些字段具有相同值的3D对象。由于这些属性是在共享组件中指定的，因此EntityManager将匹配的实体在内存中放到一起，以便渲染系统可以有效对它们进行遍历。

>注意：
过度使用共享组件可能会导致Chunk的利用率不佳，因为它涉及基于原型和共享组件字段的每个唯一值的组合来扩展所需的内存块数。使用Entity调试器查看当前的Chunk利用率，避免将不必要的字段添加到共享组件中。

如果你从实体中添加或删除组件，或者更改SharedComponent的值，则EntityManager会将实体移至其它块，必要时创建新的块。

IComponentData通常适用于实体之间变化的数据，如存储世界位置，代理的生命值，粒子的生存时间。相反，当许多实体共享某些信息时，使用ISharedComponentData更加合适。

例如，在Unity 路演中的Boid例子中，我们从同一个Prefab实例化了许多实体，因此，许多Boid实体之间的RenderMesh完全相同
```CSharp
[System.Serializable]
public struct RenderMesh : ISharedComponentData
{
    public Mesh                 mesh;
    public Material             material;

    public ShadowCastingMode    castShadows;
    public bool                 receiveShadows;
}
```
ISharedComponentData的优点在于，每个实体的内存成本实际上为0.
我们使用ISharedComponentData将所有使用相同InstanceRenderer数据的实体分组到一起，然后有效的提取所有矩阵进行渲染生成的代码简单而高效，因为数据的布局和访问时的布局完全相同。
- RenderMeshSystemV2 （参考`Packages/com.unity.entities/Unity.Rendering.Hybrid/RenderMeshSystemV2.cs`）

### SharedComponentData 的一些重要说明

- 具有相同`SharedComponentData`的实体被一起分组到同一块中。`SharedComponentData` 的索引在每一个块中存储一次，而不是每个实体存储一次。因此，`SharedComponentData`每个实体的内存开销为0.
- 可以使用`EntityQuery`来遍历所有具有相同组件类型的实体。
- 另外，可以使用`EntityQuery.SetFilter()`来专门对具有特定`SharedComponentData`值的实体进行遍历，由于数据布局，该遍历的开销较低
- 使用`EntityManager.GetAllUniqueSharedComponents`可以检索任意实体上添加的所有唯一`SharedComponentData`
- `SharedComponentData`会自动进行引用计数
- `SharedComponentData`应该尽可能少的发生更改，因为改变SharedComponentData的值会导致使用memcpy将该实体的所有数据复制到不同的Chunk中。

## 系统状态组件（System State Components）
`SystemStateComponentData` 的目的是允许你跟踪系统内部的资源，并有机会根据需要适当的创建和销毁这些资源，而不必依赖各个回调。

`SystemStateComponentData` 和 `SystemStateSharedComponentData` 分别于 `ComponentData` 和 `SharedComponentData` 完全一样，除了一个重要的方面：

1. 在销毁实体时，不删除`SystemStateComponentData`

销毁实体分为以下几步
1. 查找所有引用此特定实体ID的所有组件
2. 删除这些组件
3. 回收实体ID以供重复使用

但是，如果存在 `SystemStateComponentData` ,则不会将其移除。这使得系统有机会清除与实体ID相关联的任何资源和状态。只有在移除所有的`SystemStateComponentData`后，实体ID才会回收（为什么这么说呢？这里看不懂没关系，继续往后看就明白这句话的意思了）。

**设计 SystemStateComponentData 的 意图**

- 系统可能需要基于`ComponentData`保持内部状态，如分配资源
- 当其它系统对值和状态进行更改时，系统仍可以管理该状态。如，组件中的值更改时，或者添加或删除相关组件时。
- “无回调”是ECS设计规则中的重要组成部分。

### 示例说明

通常使用 `SystemStateComponentData` 是为了镜像用户组件，从而提供内部状态。
例如
- FooComponent(`ComponentData` , user assigned)
- FooStateComponent(`SystemComponentData` , system assigned)

**检测组件添加**

用户添加FooComponent时，FooStateComponent不存在。FooSystem更新查询不包含FooComponent，但不包含FooStateComponent的实体，来推断这些组件是刚添加到实体上的。此时，FooSystem就会给该实体添加FooStateComponent以及任何所需的内部状态。

**检测组件删除**

当用户删除FooComponent，FooStateComponent依旧存在。FooSystem更新查询包含FooStateComponent，但不包含FooComponent的实体，来推断这些组件已经被移除。此时，FooSystem将移除FooStateComponent并修复任何需要的内部状态。

**检测实体销毁**

前面提到过，销毁实体分为以下几步
1. 查找所有引用此特定实体ID的所有组件
2. 删除这些组件
3. 回收实体ID以供重复使用

但是，销毁身体时不会销毁SystemStateComponentData,并且只有在销毁最后一个组件时，才会回收实体ID。从而使得系统有机会和删除组件完全相同的方式清理内部状态。

### 具体实例

**SystemStateComponentData**

`SystemStateComponentData`的使用和`CompnentData`类似
```CSharp
struct FooStateComponent : ISystemStateComponentData
{
}
```
还可以通过组件相同的方式来控制 `SystemStateComponentData`的可见性（使用 private ,public ,internal）。然而，作为一般规则，它要求`SystemStateComponentData`在创建它的系统之外为`ReadOnly`。

**SystemStateSharedComponent**

`SystemStateSharedComponent`的使用和`SharedComponentData `类似
```CSharp
struct FooStateSharedComponent : ISystemStateSharedComponentData
{
  public int Value;
}
```

下面示例显示了一个简化的系统，该系统说明了如何使用系统状态来管理实体。示例中定义了通用IComponentData实例和系统状态ISystemStateComponentData实例。
示例还基于这些实体定义了三个查询：
- m_newEntities 选择具有通用组件，但不具有系统状态组件的实体。该查询查找系统之前没有见过的新实体。系统运行Job，通过使用新的实体查询来添加系统状态组件
- m_activeEntities 选择同时具有通用组件和系统状态组件的实体。在实际应用中，其他系统可能是处理或销毁实体的系统。
- m_destroyEntities 选择具有系统状态组件，但没有通用组件的实体。由于系统状态组件永远不会单独添加到实体上，因此，这个查询所选择的实体肯定已经被此系统或者其他系统删除了。系统使用销毁实体查询来运行Job,以便从实体中删除系统状态组件，从而可以使ECS代码回收实体ID。

>注意，这个简单的示例在系统内不维护任何状态。系统状态组件的其中一个目的是跟踪何时需要分配内存或清除持久性资源。

```CSharp
using Unity.Collections;
using Unity.Entities;
using Unity.Jobs;
using UnityEngine;

public struct GeneralPurposeComponentA : IComponentData
{
    public bool IsAlive;
}

public struct StateComponentB : ISystemStateComponentData
{
    public int State;
}

public class StatefulSystem : JobComponentSystem
{
    private EntityQuery m_newEntities;
    private EntityQuery m_activeEntities;
    private EntityQuery m_destroyedEntities;
    private EntityCommandBufferSystem m_ECBSource;

    protected override void OnCreate()
    {
        // Entities with GeneralPurposeComponentA but not StateComponentB
        m_newEntities = GetEntityQuery(new EntityQueryDesc()
        {
            All = new ComponentType[] {ComponentType.ReadOnly<GeneralPurposeComponentA>()},
            None = new ComponentType[] {ComponentType.ReadWrite<StateComponentB>()}
        });

        // Entities with both GeneralPurposeComponentA and StateComponentB
        m_activeEntities = GetEntityQuery(new EntityQueryDesc()
        {
            All = new ComponentType[]
            {
                ComponentType.ReadWrite<GeneralPurposeComponentA>(),
                ComponentType.ReadOnly<StateComponentB>()
            }
        });

        // Entities with StateComponentB but not GeneralPurposeComponentA
        m_destroyedEntities = GetEntityQuery(new EntityQueryDesc()
        {
            All = new ComponentType[] {ComponentType.ReadWrite<StateComponentB>()},
            None = new ComponentType[] {ComponentType.ReadOnly<GeneralPurposeComponentA>()}
        });

        m_ECBSource = World.GetOrCreateSystem<EndSimulationEntityCommandBufferSystem>();
    }

    struct NewEntityJob : IJobForEachWithEntity<GeneralPurposeComponentA>
    {
        public EntityCommandBuffer.Concurrent ConcurrentECB;

        public void Execute(Entity entity, int index, [ReadOnly] ref GeneralPurposeComponentA gpA)
        {
            // Add an ISystemStateComponentData instance
            ConcurrentECB.AddComponent<StateComponentB>(index, entity, new StateComponentB() {State = 1});
        }
    }

    struct ProcessEntityJob : IJobForEachWithEntity<GeneralPurposeComponentA>
    {
        public EntityCommandBuffer.Concurrent ConcurrentECB;

        public void Execute(Entity entity, int index, ref GeneralPurposeComponentA gpA)
        {
            // Process entity, possibly setting IsAlive false --
            // In which case, destroy the entity
            if (!gpA.IsAlive)
            {
                ConcurrentECB.DestroyEntity(index, entity);
            }
        }
    }

    struct CleanupEntityJob : IJobForEachWithEntity<StateComponentB>
    {
        public EntityCommandBuffer.Concurrent ConcurrentECB;

        public void Execute(Entity entity, int index, [ReadOnly] ref StateComponentB state)
        {
            // This system is responsible for removing any ISystemStateComponentData instances it adds
            // Otherwise, the entity is never truly destroyed.
            ConcurrentECB.RemoveComponent<StateComponentB>(index, entity);
        }
    }

    protected override JobHandle OnUpdate(JobHandle inputDependencies)
    {
        var newEntityJob = new NewEntityJob()
        {
            ConcurrentECB = m_ECBSource.CreateCommandBuffer().ToConcurrent()
        };
        var newJobHandle = newEntityJob.ScheduleSingle(m_newEntities, inputDependencies);
        m_ECBSource.AddJobHandleForProducer(newJobHandle);

        var processEntityJob = new ProcessEntityJob()
            {ConcurrentECB = m_ECBSource.CreateCommandBuffer().ToConcurrent()};
        var processJobHandle = processEntityJob.Schedule(m_activeEntities, newJobHandle);
        m_ECBSource.AddJobHandleForProducer(processJobHandle);

        var cleanupEntityJob = new CleanupEntityJob()
        {
            ConcurrentECB = m_ECBSource.CreateCommandBuffer().ToConcurrent()
        };
        var cleanupJobHandle = cleanupEntityJob.ScheduleSingle(m_destroyedEntities, processJobHandle);
        m_ECBSource.AddJobHandleForProducer(cleanupJobHandle);

        return cleanupJobHandle;
    }

    protected override void OnDestroy()
    {
        // Implement OnDestroy to cleanup any resources allocated by this system.
        // (This simplified example does not allocate any resources.)
    }
}
```

## 动态缓存组件（Dynamic Buffers）
动态缓存将类似数组的数据与实体关联。动态缓存是一个可以容纳可变数量元素，并根据需要自动调整大小的ECS组件。

要创建动态缓存，首先声明一个实现IBufferElementData的结构，该结构定义存储在缓冲区中的元素。例如，你可以对存储整数缓冲区组件使用以下结构：
```CSharp
public struct IntBufferElement : IBufferElementData
{
    public int Value;
}
```
要将动态缓存与实体关联，请直接向实体添加IBufferElementData组件，而不要添加[动态缓冲区容器](https://docs.unity3d.com/Packages/com.unity.entities@0.3/api/Unity.Entities.DynamicBuffer-1.html)本身。

ECS管理容器,对于大多数用途，可以将通过声明`IBufferElementData`的动态缓存组件和其他任何ECS组件一样来对待。如，你可以在实体查询，以及添加或删除缓冲区时使用IBufferElementData类型。然而，你需要使用不同的函数来访问缓存组件，这些函数提供了DynamicBuffer实例，该实例为缓存数据提供了类似数组的接口。

你可以所有InternalBufferCapacity属性为动态缓存组件指定“内部容量”。内部容量定义了动态缓存与实体的其它组件一起存储在ArchetypeChunk 中的元素的数量。如果缓冲区的大小增加到超出内部容量，则缓存将在当前块之外分配内存块（并将所有现有元素移动）。ECS会自动管理这个外部缓存区，并且在删除该组件时会自动释放其内存。

>注意
如果缓存中的数据不是动态的，可以使用Blob asset代替动态缓冲区。Blob asset可以存储数据化结构，包括数组，并且可以由多个实体共享。

### 声明缓存元素类型

要声明一个缓存，需要先声明一个要放入缓存的元素类型的结构，该结构需要实现`IBufferElementData`

```CSharp
// InternalBufferCapacity specifies how many elements a buffer can have before
// the buffer storage is moved outside the chunk.
    [InternalBufferCapacity(8)]
    public struct MyBufferElement : IBufferElementData
    {
        // Actual value each buffer element will store.
        public int Value;

        // The following implicit conversions are optional, but can be convenient.
        public static implicit operator int(MyBufferElement e)
        {
            return e.Value;
        }

        public static implicit operator MyBufferElement(int e)
        {
            return new MyBufferElement {Value = e};
        }
    }
```

**给实体添加缓存类型**
要将缓存添加给实体，需要先定义缓存元素数据类型的`IBufferElementData`结构，然后将该类型直接添加给实体或原型。

1. 通过`EntityManager.AddBuffer()`添加
```CSharp
EntityManager.AddBuffer<MyBufferElement>(entity);
```
2. 通过原型添加
```CSharp
Entity e = EntityManager.CreateEntity(typeof(MyBufferElement));
```
3. 通过EntityCommandBuffer添加
你可以在添加命令到实体命令缓冲区时，可以添加或设置缓存组件。使用`AddBuffer`为实体创建新的缓存，从而改变实体的原型。使用`SetBuffer`清除现有的缓存（必须是一个存在的缓存），并在该位置创建一个新的空缓存。这两个函数都返回一个DynamicBuffer实例，你可以使用该实例来填充新的缓存。你可以立即将元素添加到缓存，但是，在执行命令缓冲区，将缓存中的内容添加到实体之前，都无法访问它们。

下面的Job使用命令缓冲区创建一个新的实体，然后使用`EntityCommandBuffer.AddBuffer`添加动态缓存组件。Job 还向动态缓存添加了许多元素。

```CSharp
struct DataSpawnJob : IJobForEachWithEntity<DataToSpawn>
{
    // A command buffer marshals structural changes to the data
    public EntityCommandBuffer.Concurrent CommandBuffer;

    //The DataToSpawn component tells us how many entities with buffers to create
    public void Execute(Entity spawnEntity, int index, [ReadOnly] ref DataToSpawn data)
    {
        for (int e = 0; e < data.EntityCount; e++)
        {
            //Create a new entity for the command buffer
            Entity newEntity = CommandBuffer.CreateEntity(index);

            //Create the dynamic buffer and add it to the new entity
            DynamicBuffer<MyBufferElement> buffer =
                CommandBuffer.AddBuffer<MyBufferElement>(index, newEntity);

            //Reinterpret to plain int buffer
            DynamicBuffer<int> intBuffer = buffer.Reinterpret<int>();

            //Optionally, populate the dynamic buffer
            for (int j = 0; j < data.ElementCount; j++)
            {
                intBuffer.Add(j);
            }
        }

        //Destroy the DataToSpawn entity since it has done its job
        CommandBuffer.DestroyEntity(index, spawnEntity);
    }
}
```

>注意：
不需要立即将数据添加到动态缓存。但是，直到执行了你正在使用的实体命令缓冲区，你才能再次访问该缓冲区

### 缓存的访问
你可以使用EntityManager，系统，和Job 来访问DynamicBuffer实例，其方式与访问实体的其他组件相同。

1. EntityManager
你可以使用EntityManager的实例来访问动态缓存
```CSharp
DynamicBuffer<MyBufferElement> dynamicBuffer
    = EntityManager.GetBuffer<MyBufferElement>(entity);
```

2. Component System Entities.ForEach
你也可以在Component System中访问动态缓存
```CSharp
public class DynamicBufferSystem : ComponentSystem
{
    protected override void OnUpdate()
    {
        var sum = 0;

        Entities.ForEach((DynamicBuffer<MyBufferElement> buffer) =>
        {
            foreach (var integer in buffer.Reinterpret<int>())
            {
                sum += integer;
            }
        });

        Debug.Log("Sum of all buffers: " + sum);
    }
}
```

3. 查找另一个实体的缓存
当你需要在Job中查找另一个实体的缓存时，你可以传递  `BufferFromEntity`，也可以从JobComponentSystem的每个实体中查找缓存。
```CSharp
BufferFromEntity<MyBufferElement> lookup = GetBufferFromEntity<MyBufferElement>();
var buffer = lookup[entity];
buffer.Add(17);
buffer.RemoveAt(0);
```

4. IJobForEach
还可以访问IJobForEach处理的实体所关联的动态缓存。

在 IJobforEach 或 IJobForEachWithEntity 声明中，将缓存中的元素作为通用参数之一。如：

```CSharp
public struct BuffersByEntity : IJobForEachWithEntity_EB<MyBufferElement>{
}
```

但在Job结构的`Execute()`方法中，使用DynamicBuffer<T>作为参数类型，如
```CSharp
public void Execute(Entity entity, int index, DynamicBuffer<MyBufferElement> buffer){}
```

下面的示例将所有的动态缓存内容累计起来，其中包含类型为 MyBufferElement 的元素。由于IJobForEach Job 并行处理实体，因此，该示例首先将每个缓存的单独计算的和存储到Native Array中，然后使用第二个Job来计算最终和。

```CSharp
public class DynamicBufferForEachSystem : JobComponentSystem
{
    private EntityQuery query;

    protected override void OnCreate()
    {
        EntityQueryDesc queryDescription = new EntityQueryDesc();
        queryDescription.All = new[] {ComponentType.ReadOnly<MyBufferElement>()};
        query = GetEntityQuery(queryDescription);
    }

    //Sums the elements of individual buffers of each entity
    public struct BuffersByEntity : IJobForEachWithEntity_EB<MyBufferElement>
    {
        public NativeArray<int> sums;

        public void Execute(Entity entity,
            int index,
            DynamicBuffer<MyBufferElement> buffer)
        {
            foreach (int integer in buffer.Reinterpret<int>())
            {
                sums[index] += integer;
            }
        }
    }

    //Sums the intermediate results into the final total
    public struct SumResult : IJob
    {
        //此特性表示Job完成后马上释放内存
        [DeallocateOnJobCompletion] public NativeArray<int> sums;

        public void Execute()
        {
            int sum = 0;
            foreach (int integer in sums)
            {
                sum += integer;
            }

            //Note: Debug.Log is not burst-compatible
            Debug.Log("Sum of all buffers: " + sum);
        }
    }

    //Schedules the two jobs with a dependency between them
    protected override JobHandle OnUpdate(JobHandle inputDeps)
    {
        //Create a native array to hold the intermediate sums
        int entitiesInQuery = query.CalculateEntityCount();
        NativeArray<int> intermediateSums
            = new NativeArray<int>(entitiesInQuery, Allocator.TempJob);

        //Schedule the first job to add all the buffer elements
        BuffersByEntity bufferJob = new BuffersByEntity();
        bufferJob.sums = intermediateSums;
        JobHandle intermediateJob = bufferJob.Schedule(this, inputDeps);

        //Schedule the second job, which depends on the first
        SumResult finalSumJob = new SumResult();
        finalSumJob.sums = intermediateSums;
        return finalSumJob.Schedule(intermediateJob);
    }
}
```
5. IJobChunk
要访问IJobChunk Job中的单个缓存，需要先将缓存数据类型传递给该Job，然后使用该数据类型获取BufferAccessor。缓存访问器是一种类似于数组的结构，可提供对当前块中所有动态缓存的访问。

与前面的IJobForEach 示例一样，下面的示例将所有其类型为MyBufferElement的动态缓存的所有内容加起来。IJobChunk Job可以在每个块上并行运行，因此此示例也是分别先计算每个缓存的和，存储到Nattive Array上，然后使用第二个Job来计算最终和。这种情况下，中间数组为每个块保存一个结果，而不是为每一个实体保存一个（前面的例子就是每个实体保存一个）。

```CSharp
public class DynamicBufferJobSystem : JobComponentSystem
{
    private EntityQuery query;

    protected override void OnCreate()
    {
        //Create a query to find all entities with a dynamic buffer
        // containing MyBufferElement
        EntityQueryDesc queryDescription = new EntityQueryDesc();
        queryDescription.All = new[] {ComponentType.ReadOnly<MyBufferElement>()};
        query = GetEntityQuery(queryDescription);
    }

    public struct BuffersInChunks : IJobChunk
    {
        //The data type and safety object
        public ArchetypeChunkBufferType<MyBufferElement> BufferType;

        //An array to hold the output, intermediate sums
        public NativeArray<int> sums;

        public void Execute(ArchetypeChunk chunk,
            int chunkIndex,
            int firstEntityIndex)
        {
            //A buffer accessor is a list of all the buffers in the chunk
            BufferAccessor<MyBufferElement> buffers
                = chunk.GetBufferAccessor(BufferType);

            for (int c = 0; c < chunk.Count; c++)
            {
                //An individual dynamic buffer for a specific entity
                DynamicBuffer<MyBufferElement> buffer = buffers[c];
                foreach (MyBufferElement element in buffer)
                {
                    sums[chunkIndex] += element.Value;
                }
            }
        }
    }

    //Sums the intermediate results into the final total
    public struct SumResult : IJob
    {
        [DeallocateOnJobCompletion] public NativeArray<int> sums;

        public void Execute()
        {
            int sum = 0;
            foreach (int integer in sums)
            {
                sum += integer;
            }

            //Note: Debug.Log is not burst-compatible
            Debug.Log("Sum of all buffers: " + sum);
        }
    }

    protected override JobHandle OnUpdate(JobHandle inputDeps)
    {
        //Create a native array to hold the intermediate sums
        int chunksInQuery = query.CalculateChunkCount();
        NativeArray<int> intermediateSums
            = new NativeArray<int>(chunksInQuery, Allocator.TempJob);

        //Schedule the first job to add all the buffer elements
        BuffersInChunks bufferJob = new BuffersInChunks();
        bufferJob.BufferType = GetArchetypeChunkBufferType<MyBufferElement>();
        bufferJob.sums = intermediateSums;
        JobHandle intermediateJob = bufferJob.Schedule(query, inputDeps);

        //Schedule the second job, which depends on the first
        SumResult finalSumJob = new SumResult();
        finalSumJob.sums = intermediateSums;
        return finalSumJob.Schedule(intermediateJob);
    }
}
```

### 重解释缓存(Reinterpreting Buffers)

缓存可以重新解析为相同大小的类型，目的是允许控制类型双关，并在它们摆脱包装元素的阻碍。通过调用`Reinterpret<T>`进行重解析:

```CSharp
DynamicBuffer<int> intBuffer
    = EntityManager.GetBuffer<MyBufferElement>(entity).Reinterpret<int>();
```

重解析的缓存示例保留了原始缓存的安全性，并且可以安全的使用。重解析的缓存引用着元素的数据，因此，对一个重解析的缓存进行修改，会立即反应给其他引用此缓存的对象。

注意：
重解析函数仅仅强制所涉及的类型具有相同的长度。如，你可以将unit缓存使用float缓存来解析而不会引发错误，因为它们的元素类型的长度都是32位。你应该确保重解析在逻辑上是有意义的。

## 块组件（Chunk component data）

使用块组件将数据与特殊的块关联。

块组件的数据，适用于特定块中的所有实体。例如，如果你有按接近程度组织的3D对象的实体块，则可以使用块组件将实体的集体边界框存储在块中，块组件使用IComponentData接口类型。

使用添加和设置块组件的值 尽管可以使得块组件可以有唯一值给一个块，但是它们也是块中的实体的原型的一部分。因此，如果你从实体在删除了一个块组件，则这个实体就会移动到另一个块（也可能是新建一个块）。同样，如果给实体添加一个块组件，则由于其实体原型改变，该实体将移动到其他块。块组件的添加不会影响原始块中的其余实体。

如果使用该块中的实体更改块组件的值，则它将更改该块中所有实体共有的块组件的值。如果修改实体的原型，使其碰巧移动到具有相同类型的块组件的块中，那么目标块中的值不会受到影响。（如果将实体移动到新建的块，则还将为该块创建一个新的块组件，并为其分配默认值）

使用块组件和通用组件之间的主要区别在于，你使用不同的函数来添加，设置和删除它们。块组件还具有自己的ComponentType函数，用于定义实体原型和查询。

相关APIs

- 声明

|目的|函数|
|-|-|
|Declaration|IComponentData|

- 原型块方法

|目的|函数|
|-|-|
|Read|GetChunkComponentData(ArchetypeChunkComponentType)|
|Check|HasChunkComponent(ArchetypeChunkComponentType)|
|Write|SetChunkComponentData(ArchetypeChunkComponentType, T)|

- EntityManager 方法

|目的|函数|
|-|-|
|Create|AddChunkComponentData(Entity)|
|Create|AddChunkComponentData(EntityQuery, T)|
|Create|AddComponents(Entity,ComponentTypes)|
|Get type info|GetArchetypeChunkComponentType(Boolean)|
|Read|GetChunkComponentData(ArchetypeChunk)|
|Read|GetChunkComponentData(Entity)|
|Check|GetArchetypeChunkComponentType(Boolean)|
|Delete|RemoveChunkComponent(Entity)|
|Delete|RemoveChunkComponent(ArchetypeChunk)|
|Write|EntityManager.SetChunkComponentData(ArchetypeChunk, T)|

### 声明块组件

块组件使用`IComponentData`接口类型
```CSharp
public struct ChunkComponentA : IComponentData
{
    public float Value;
}
```

### 创建块组件
你可以直接创建一个块组件，通过使用目标块中的一个实体，或者使用选取一组目标块的实体查询。块组件不可以在Job中添加，也不能通过EntityCommandBuffer添加。

你还可以将块组件作为EntityArchetype的一部分，或作为用来创建实体的ComponentType对象列表中的一部分，并为该原型的每个存储块的实体创建块组件。在这些方法需要使用`ComponentType.ChunkComponent<T>` 或 `ComponentType.ChunkComponentReadOnly<T>`，否则该组件将被视为通用组件而不是块组件。

1. 通过块中的实体
给定目标块中的一个实体，你可以通过`EntityManager.AddChunkComponentData<T>() `函数给该块添加块组件：
```CSharp
EntityManager.AddChunkComponentData<ChunkComponentA>(entity);
```
通过这个方法创建块组件时，你无法立即设置块组件的值。

2. 通过实体查询（EntityQuery）

给定一个实体查询来获取所有你想添加块组件的块，你可以通过 `EntityManager.AddChunkComponentData<T>() `函数添加块组件。
```CSharp
EntityQueryDesc ChunksWithoutComponentADesc = new EntityQueryDesc()
{
    None = new ComponentType[] {ComponentType.ChunkComponent<ChunkComponentA>()}
};
ChunksWithoutChunkComponentA = GetEntityQuery(ChunksWithoutComponentADesc);

EntityManager.AddChunkComponentData<ChunkComponentA>(ChunksWithoutChunkComponentA,
        new ChunkComponentA() {Value = 4});
```
通过这个方法，你可以为所有新块组件添加初始值

3. 通过实体原型（EntityArchtype）

当通过原型或者组件类型列表 来添加实体时，可以将块组件包含在其中：
```CSharp
ArchetypeWithChunkComponent = EntityManager.CreateArchetype(
    ComponentType.ChunkComponent(typeof(ChunkComponentA)),
    ComponentType.ReadWrite<GeneralPurposeComponentA>());
var entity = EntityManager.CreateEntity(ArchetypeWithChunkComponent);
```
或者使用组件类型列表
```CSharp
ComponentType[] compTypes = {ComponentType.ChunkComponent<ChunkComponentA>(),
                             ComponentType.ReadOnly<GeneralPurposeComponentA>()};
var entity = EntityManager.CreateEntity(compTypes);
```
使用这些方法，作为实体构建的一部分创建的新块的块组件将使用默认值。现有块的块组件不会更改（现有块中可能还存在其他的块组件）。


### 读取块组件

你可以使用代表数据块的ArchetypeChunk对象或使用目标块中的实体来读取块组件。

1. 通过ArchetypeChunk 实例
给定一个块，你可以使用 `EntityManager.GetChunkComponentData<T>`读取块组件。下面代码遍历所有匹配查询的块，并访问ChunkComponentA类型的块组件：
```CSharp
var chunks = ChunksWithChunkComponentA.CreateArchetypeChunkArray(Allocator.TempJob);
foreach (var chunk in chunks)
{
    var compValue = EntityManager.GetChunkComponentData<ChunkComponentA>(chunk);
    //..
}
chunks.Dispose();
```

2. 通过块中的实体

给定实体，你可以通过`EntityManager.GetChunkComponentData<T>`访问实体所在块的块组件：
```CSharp
if(EntityManager.HasChunkComponent<ChunkComponentA>(entity))
    chunkComponentValue = EntityManager.GetChunkComponentData<ChunkComponentA>(entity);
```

你也可以通过 [流式 查询](https://en.wikipedia.org/wiki/Fluent_interface) 来只获取拥有块组件的实体

```CSharp
Entities.WithAll(ComponentType.ChunkComponent<ChunkComponentA>()).ForEach(
    (Entity entity) =>
{
    var compValue = EntityManager.GetChunkComponentData<ChunkComponentA>(entity);
    //...
});
```

>注意：
你无法将块组件传递给查询的for-each部分，并且，你必须传递Entity对象并使用EntityManager来访问块组件

### 更新块组件
你可以通过给定块的引用来修改块组件。在IJobChunk job 中，可以调用`ArchetypeChunk.SetChunkComponentData`。在主线程中，则使用`EntityManger.SetChunkComponentData`。注意，你无法在IJobForEach job 中访问块组件，因为无权访问ArchetypeChunk对象或者EntityManager。
1. 通过ArchetypeChunk 实例

在Job中更新块组件 ，参考 [在JobComponentSystem中读写](#1)

在主线程中更新块组件，使用EntityManager:
```CSharp
EntityManager.SetChunkComponentData<ChunkComponentA>(chunk,new ChunkComponentDataA(){Value = 7});
```

2. 通过块中的实体
如果你只有块中的一个实体而不是块本身的引用，你也可以通过使用EntityManager 来获取该实体所属块：

```CSharp
var entityChunk = EntityManager.GetChunk(entity);
EntityManager.SetChunkComponentData<ChunkComponentA>(entityChunk,
                    new ChunkComponentA(){Value = 8});
```

3. 检测数据变化
使用组件变更版本来检测何时需要为给定块更新块组件。只要以可写的方式访问组件中的数据，或者从该块中添加或删除实体，ECS都会更新该块的组件版本。

例如，如果块组件包含通过实体的LocalToWorld组件计算出块中实体的中心点，则可以检查LocalToWorld组件的版本以确定是否应该更新块组件（即，只要其中一个实体的坐标发生了变换，就会影响到该块中所有实体的中心点）。如果你的块组件是从多个组件派生的，则应该检查所有组件的版本，以查看它们是否有任何更改。

另外，可以查阅[跳过具有不变实体的块]()

<a name="1" ></a>
### 在JobComponentSystem中读写
在JobComponentSystem内的IJobChunk中，可以使用传递给`IJobChunk.Execute()`的chunk参数来访问块组件。与IJobChunk Job 中的任何组件数据一样，你必须使用`ArchetypeChunkComponentType <T>`对象传递给Job的字段才能访问该组件。

下面的系统定义了一个查询，该查询筛选所有具有ChunkComponentA类型块组件的实体和块。然后，它使用该查询运行IJobChunk Job,来遍历所选块并访问各个块组件。Job 使用 ArchetypeChunk 的 GetChunkComponentData 和 SetChunkComponentData函数来读取和写入块组件数据。

```CSharp
using Unity.Burst;
using Unity.Entities;
using Unity.Jobs;

public class ChunkComponentChecker : JobComponentSystem
{
  private EntityQuery ChunksWithChunkComponentA;
  protected override void OnCreate()
  {
      EntityQueryDesc ChunksWithComponentADesc = new EntityQueryDesc()
      {
        All = new ComponentType[]{ComponentType.ChunkComponent<ChunkComponentA>()}
      };
      ChunksWithChunkComponentA = GetEntityQuery(ChunksWithComponentADesc);
  }

  [BurstCompile]
  struct ChunkComponentCheckerJob : IJobChunk
  {
      public ArchetypeChunkComponentType<ChunkComponentA> ChunkComponentATypeInfo;
      public void Execute(ArchetypeChunk chunk, int chunkIndex, int firstEntityIndex)
      {
          var compValue = chunk.GetChunkComponentData(ChunkComponentATypeInfo);
          //...
          var squared = compValue.Value * compValue.Value;
          chunk.SetChunkComponentData(ChunkComponentATypeInfo,
                      new ChunkComponentA(){Value= squared});
      }
  }

  protected override JobHandle OnUpdate(JobHandle inputDependencies)
  {
    var job = new ChunkComponentCheckerJob()
    {
      ChunkComponentATypeInfo = GetArchetypeChunkComponentType<ChunkComponentA>()
    };
    return job.Schedule(ChunksWithChunkComponentA, inputDependencies);
  }
}
```

>注意：
如果仅读取块组件而不是写入，则在定义实体查询时应该使用`ComponentType.ChunkComponentReadOnly`，以避免创建不必要的Job调度约束。

### 删除块组件

使用 EntityManager.RemoveChunkComponent 函数 来删除块组件。你可以删除目标块中的一个实体上的块组件，或删除实体查询得到的所有块上面的某类型的块组件。如果你从单个实体上删除块组件，该实体将会移除到不同的块中，因为其原型发生了改变；只要该块中还有其他实体，块自身就会保持未更改的块组件。

### 在查询中使用块组件
要在山体查询中使用块组件，必须使用 `ComponentType.ChunkComponent <T>`或`ComponentType.ChunkComponentReadOnly <T>`函数来指定类型，否则，该组件就会被视为通用组件，而不是块组件。

1. 在 EntityQueryDesc 中
下面的查询可用来创建一个实体查询，该查询选择所有块类型为 ChunkComponentA 的块（以及这些块中的实体）。
```CSharp
EntityQueryDesc ChunksWithChunkComponentADesc = new EntityQueryDesc()
{
    All = new ComponentType[]{ComponentType.ChunkComponent<ChunkComponentA>()}
};
```

2. 在EntityQueryBuilder 的 lambda 函数中
以下的流式查询 遍历块中具有 ChunkComponentA 类型的块组件的所有实体：
```CSharp
Entities.WithAll(ComponentType.ChunkComponentReadOnly<ChunkCompA>())
        .ForEach((Entity ent) =>
{
    var chunkComponentA = EntityManager.GetChunkComponentData<ChunkCompA>(ent);
});
```

>注意：
你不能把块组件传递给lambda函数本身。要在流式查询中读取或写入块组件的值，请使用 ComponentSystem.EntityManager属性。修改块组件可以有效的修改同一个块中所有实体的值，且不会将当前实体移动到其他块。
