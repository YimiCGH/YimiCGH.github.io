---
layout: post
title: 'Unity ECS 研究 06 —— 实体查询'
categories:
      - 翻译
tags:
  - ECS
  - Unity
last_modified_at: 2019-12-18T23:00:00-23:00
---
{% include toc %}
---
## EntityQuery
读取或写入数据的前提是找到该数据。ECS框架中的数据存储在组件中，这些组件根据它们所属原型在内存中分组到一起。要定义你的ECS数据视图仅包含指定数据，来给你的算法或流程使用，你需要使用`EntityQuery`结构。

创建一个`EntityQuery`后，你可以：
- 运行job来处理该视图选择的实体或组件
- 获取一个包含所有选择实体的NativeArray
- 获取所有选择组件的NativeArrays（通过组件类型获取）

`EntityQuery`确保返回的实体和组件数组是"平行"的，即，任何数组中的相同索引始终对应同一个实体。

>注意：
`System.Entities.ForEach`委托和 `IJobForEach`会基于你为这些APIs指定的组件类型和特性在内部创建一个EntityQuery

## 定义查询
`EntityQuery`查询定义了原型必须包含的一组组件类型，以便其的块和实体包含在视图中（即查询结果中）。你也可以排除包含特定类型的类型组件的原型。

对于简单查询，你可以基于一些列组件创建EntityQuery。下面例子定义了一个EntityQuery，该查询选择具有RotationQuaternion和RotationSpeed组件的所有实体。
```CSharp
EntityQuery m_Query = GetEntityQuery(
  typeof(RotationQuaternion),
  ComponentType.ReadOnly<RotationSpeed>()
);
```
该查询使用 `ComponentType.ReadOnly`,而不是简单的`typeof`表达式来指定系统不写入RotationSpeed。尽可能的始终指定只读，因为对数据的限制比较少，可以帮助job调度程序更加高效的执行job。

## EntityQueryDesc

对于更加复杂的查询，可以使用`EntityQueryDesc`来创建EntityQuery，它提供了一种灵活的查询机制，可以根据以下几组组件集来选择原型：
- All : 原型必须包含数组中所有类型的组件
- Any : 原型必须至少包含数组中任意一种组件
- None : 原型不能包含数组中任意一种组件

例如，以下查询选择包含RotationQuaternion和RotationSpeed组件，但不包含Frozen组件的任何原型：
```CSharp
var query = new EntityQueryDesc
{
   None = new ComponentType[]{ typeof(Frozen) },
   All = new ComponentType[]{ typeof(RotationQuaternion), ComponentType.ReadOnly<RotationSpeed>() }
}
EntityQuery m_Query = GetEntityQuery(query);
```
>注意：
请不要在`EntityQueryDesc`中包括完整的可选组件。要处理可选组件，请使用`ArchetypeChunk.Has<T>()`方法确定当前ArchetypeChunk是否具有可选组件。之所以不需要包括完整的可选组件，是由于同一个块中的所有实体具有完全相同的组件类型，因此，你只需要检查每个块是否存在一个可选组件，而不是每个实体一次。

## 查询选项

创建EntityQueryDesc时，可以设置其Options变量。这些选项允许进行专门的查询（通常不需要设置它们）
- Default ： 没有设置选项，正常的查询行为。
- IncludePrefab : 包括包含特殊Prefab标签组件的原型
- IncludeDisabled ： 包括包含特殊的禁用标签组件的原型。
- FilterWriteGroup : 考虑查询中任何组件的WriteGroup。

设置`FilterWriteGroup`选项时，只有拥有那些在明确包含在查询的写入组中的组件的实体，才会包含进视图。而那些拥有同一写入组中的其他组件的实体，将会被排除。

例如，假设C2 和C3是基于C1的同一写入组中的组件，并且你使用`FilterWriteGroup`创建需要C1和C3的查询：
```CSharp
public struct C1: IComponentData{}

[WriteGroup(C1)]
public struct C2: IComponentData{}

[WriteGroup(C1)]
public struct C3: IComponentData{}

// ... In a system:
var query = new EntityQueryDesc{
    All = new ComponentType{typeof(C1), ComponentType.ReadOnly<C3>()},
    Options = EntityQueryDescOptions.FilterWriteGroup
};
var m_Query = GetEntityQuery(query);
```

该查询排除同时具有C2和C3的的所有实体，因为查询没有明确指定包含C2。尽管你可以使用`None`将其设计到查询中，但是使用Write Group 有一个重要的好处：你不需要更改其它系统使用的查询（只要这些系统也使用了Write Group）。

Write Group 是一种允许扩展现有系统的机制。例如，如果C1和C2是在另一个系统中定义的（也许是你无法控制的库的一部分），你可以将C3和放到和C2一样的写入组中，来更改C1的更新方式。对于任意要添加C3组件的实体，你的系统将更新C1，而原始系统则不会。对于其它没有C3的实体，原始系统将像以前一样更新。

更多信息请参考[Write Group]()

### 合并查询
你还可以通过传递EntityQueryDesc对象的数组而不是单个实例来组合多个查询。每个查询都使用逻辑或运算进行组合。以下示例选择包含RotationQuaternion组件或RotationSpeed组件（或两者都有）的原型：
```CSharp
var query0 = new EntityQueryDesc
{
   All = new ComponentType[] {typeof(RotationQuaternion)}
};

var query1 = new EntityQueryDesc
{
   All = new ComponentType[] {typeof(RotationSpeed)}
};

EntityQuery m_Query = GetEntityQuery(new EntityQueryDesc[] {query0, query1});

```

和或逻辑一样，查询实体时，对EntityQueryDesc中的每个查询逐个进行匹配，只要实体满足其中一个就添加进视图，并终止后续查询的检测。

## 创建EntityQuery

在系统类之外，可以使用`EntityManager.CreateEntityQuery（）`函数创建`EntityQuery`：
```CSharp
EntityQuery m_Query = CreateEntityQuery(
  typeof(RotationQuaternion),
  ComponentType.ReadOnly<RotationSpeed>()
);
```

但是，在系统类内部，必须使用GetEntityQuery（）函数：
```CSharp
public class RotationSpeedSystem : JobComponentSystem
{
   private EntityQuery m_Query;
   protected override void OnCreate()
   {
       m_Query = GetEntityQuery(typeof(RotationQuaternion), ComponentType.ReadOnly<RotationSpeed>());
   }
   //…
}
```

当你打算重用同一视图时，应尽可能缓存EntityQuery实例，而不是为每次使用创建一个新实例。
例如，在系统中，您可以在系统的`OnCreate（）`函数中创建`EntityQuery`并将结果存储在实例变量中。
上例中的m_Query变量用于此目的。

## 定义过滤器
除了定义必须包含在查询中或从查询中排除的组件之外，您还可以过滤视图。您可以指定以下类型的过滤器：
- 共享组件值：根据共享组件的特定值过滤实体集。
- 更改过滤器：根据特定组件类型的值是否可能更改 来 过滤实体集

### 共享组件过滤器
若要使用共享组件筛选器，请首先将共享组件包括在EntityQuery中（随着其他所需组件一起），然后调用`SetFilter（）`函数，并传入具有相同ISharedComponent类型的结构，该结构包含要选择的值。所有值必须匹配。你最多可以向过滤器添加两个不同的共享组件。

你可以随时更改过滤器，但是更改过滤器不会更改从组`ToComponentDataArray（）`或`ToEntityArray（）`函数接收到的任何现有实体或组件数组。您必须重新创建这些数组。

以下示例定义了一个名为SharedGrouping的共享组件，以及一个仅处理Group字段设置为1的实体的系统：
```CS
struct SharedGrouping : ISharedComponentData
{
    public int Group;
}

class ImpulseSystem : ComponentSystem
{
    EntityQuery m_Query;

    protected override void OnCreate(int capacity)
    {
        m_Query = GetEntityQuery(typeof(Position), typeof(Displacement), typeof(SharedGrouping));
    }

    protected override void OnUpdate()
    {
        // Only iterate over entities that have the SharedGrouping data set to 1
        m_Query.SetFilter(new SharedGrouping { Group = 1 });

        var positions = m_Query.ToComponentDataArray<Position>(Allocator.Temp);
        var displacememnts = m_Query.ToComponentDataArray<Displacement>(Allocator.Temp);

        for (int i = 0; i != positions.Length; i++)
            positions[i].Value = positions[i].Value + displacememnts[i].Value;
    }
}

```

### 变更过滤器

如果仅在组件值更改后才需要更新实体，则可以使用`SetFilterChanged（）`函数将该组件添加到EntityQuery过滤器中。
例如，以下EntityQuery仅包括来自已将另一个系统写入转换组件的块的实体：
```CS
protected override void OnCreate(int capacity)
{
    m_Query = GetEntityQuery(typeof(LocalToWorld), ComponentType.ReadOnly<Translation>());
    m_Query.SetFilterChanged(typeof(Translation));
}
```

>注意
为了提高效率，更改过滤器应用于整个块，而不是单个实体。
更改过滤器仅检查系统是否已运行了已声明对组件进行写访问的系统，而不检查它是否实际上更改了任何数据。
换句话说，如果一个块已被另一个能够写入该类型组件的Job所访问，则更改筛选器将包括该块中的所有实体。
（这就为什么是始终要求对不需要修改的组件设置只读访问权的另一个原因。）

## 执行查询

当您在Job中使用EntityQuery，或调用EntityQuery方法之一返回视图中的实体，组件或块的数组的时，EntityQuery将执行其查询
- `ToEntityArray()`:返回所选实体的数组。
- `ToComponentDataArray<T>()`:返回所选实体的类型为T的组件的数组。。
- `CreateArchetypeChunkArray()`:返回包含所选实体的所有块。（由于查询对原型，共享组件值和更改过滤器进行的操作，对于块中的所有实体都是相同的，因此存储在返回的块集中的实体集，与由ToEntityArray（）返回的实体集完全相同）

## 在Jobs中使用查询

在`JobComponentSystem`中，有时只是靠Job结构的定义可能无法满足我们的筛选，这时候，就需要使用`EntityQueryDesc`提供的灵活查询来帮助我们选择实体和块，在系统的`OnCreate()`中使用`EntityQueryDesc`创建并缓存EntityQuery对象，将EntityQuery对象传递给系统的`Schedule()`方法。

在以下示例中，从HelloCube IJobChunk示例中，m_Query参数是EntityQuery对象：
```CS
// OnUpdate runs on the main thread.
protected override JobHandle OnUpdate(JobHandle inputDependencies)
{
    var rotationType = GetArchetypeChunkComponentType<Rotation>(false);
    var rotationSpeedType = GetArchetypeChunkComponentType<RotationSpeed>(true);

    var job = new RotationSpeedJob()
    {
        RotationType = rotationType,
        RotationSpeedType = rotationSpeedType,
        DeltaTime = Time.deltaTime
    };

    return job.Schedule(m_Query, inputDependencies);
}
```

EntityQuery在内部使用Jobs来创建所需的数组。当您将组传递给`Schedule（）`方法时，EntityQuery jobs与系统自己的jobs一起被调度，并且可以利用并行处理。
