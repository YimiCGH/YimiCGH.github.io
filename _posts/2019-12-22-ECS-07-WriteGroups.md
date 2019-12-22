---
layout: post
title: 'Unity ECS 研究 07 —— WriteGroups'
categories:
      - 翻译
tags:
  - ECS
  - Unity
last_modified_at: 2019-12-18T23:00:00-23:00
---
{% include toc %}
---
## WriteGroups
常见的ECS模式是系统读取一组输入组件然后输入另一组组件。但是，你可以覆盖该系统，并根据自己的输入即更新输出组件。

WriteGroups允许您覆盖系统是否写入组件，而不必更改覆盖的系统。WriteGroup标识一组组件，这些组件用作写入特定组件的源。定义WriteGroup的系统还必须对用于选择要更新的实体的EntityQuery对象启用WriteGroup筛选。

使用WriteGroup特性定义一个WriteGroup。此特性将目标输出组件的类型作为参数。将特性放在每个作为更新目标组件时的源的组件上。例如，以下声明指定组件A是WriteGroup定位组件W的一部分：
```CS
[WriteGroup(typeof(W))]
public struct A : IComponentData{ public int Value; }
```
>请注意，WriteGroup的目标组件必须包含在查询中并以可写方式访问。否则，该查询将忽略WriteGroup。

当您在查询中打开WriteGroup筛选时，查询会将WriteGroup中的所有组件添加到查询的`None`列表中，除非您明确将它们添加到`All`或`Any`列表中。
结果是，查询仅选择那些拥有明确指定的，WriterGroup中的组件类型的实体。如果实体还具有没有被明确指定的，来自该WriteGroup中的一个或多个其他组件，则查询将拒绝它。（因为前面说过，查询会将WriteGroup中的所有组件添加到查询的`None`列表中，所以不允许拥有WriteGroup中的任意组件，除非该组件被显式添加到`All`，或`Any`列表中）。

自此，WriteGroups不会做任何事情，你无法仅重写查询就可以实现（因为也不知道你具体想要做什么）。
但是，当您使用无法重写的系统时，这会带来好处。你可以将自己的组件添加到该系统定义的任何WriteGroup中，并且当将该组件与现有组件一起放置在实体上时，系统不再选择并更新该实体。然后，你自己的系统可以更新实体，而无需与其他系统竞争。

>**需要注意两种情况：**
>- 被重写的系统启用了WriteGroups：
那么当你把自己的组件添加到该系统定义的WriteGroup中，并且给该系统查询筛选的实体添加上你自己的组件，这时候，该系统就会全部抛弃那些实体，因为这些实体不再满足自己的查询，因为这些实体上出现了同一WriteGroup的组件，且没有被明确指定需要该组件。而你自己的系统，可以正确得到这些实体，执行新系统的处理。
>
>- 被重写系统没有启用WriteGroup:
这种情况，你添加同一WriteGroup组件到实体上时，不会影响原系统的查询，因此，原系统会正常运行。而你只是扩展了该系统。在你的系统上为这些实体扩展新的行为。

### WriteGroup 示例
已知,组件A和B在一个指向组件W的WriteGroup 中。
```CS
public struct W: IComponentData{}

[WriteGroup(W)]
public struct A: IComponentData{}

[WriteGroup(W)]
public struct B: IComponentData{}
```

实体X,Y的组件情况

|Entity/Component|Component A|Component B|Component W|
|-|-|-|-|
|entity X|✔|✖|✔|
|entity Y|✔|✔|✔|

然后使用查询
```CS
// ... In a system:
var query = new EntityQueryDesc{
    All = new ComponentType{
      ComponentType.ReadOnly<A>(),
      ComponentType.ReadOnly<W>()
    },
    Options = EntityQueryDescOptions.FilterWriteGroup
};
var m_Query = GetEntityQuery(query);
```

这个查询 简单记为
Quewy
- All:A,W
- WriteGroup filter: enabled

该查询选择的结果是实体 A。实体Y因为拥有同一WriteGroup中的另一个组件B，且没有出现在All列表中，因此实体Y不满足。启用WriteGroup筛选其本质其实就是(不能包含同一写入组中，且没有被写入All,Any列表的组件)：
Quewy
- All:A,W
- None:B

如果没有启用 WriteGroup filter，实体X和Y都会被查询选择。

有关更多示例，您可以查看Unity.Transforms代码，该代码对其更新的每个组件（包括LocalToWorld）使用WriteGroups

## 创建 WriteGroups
您可以通过将WriteGroup特性添加到WriteGroup中每个组件的声明中来创建WriteGroup。
WriteGroup属性采用一个参数，该参数是组中组件用于更新的组件的类型。
一个组件可以是多个WriteGroup的成员。
例如，如果组件W = A + B，则可以为W定义一个WriteGroup，如下所示：
```CS
public struct W : IComponentData
{
   public int Value;
}

[WriteGroup(typeof(W))]
public struct A : IComponentData
{
   public int Value;
}

[WriteGroup(typeof(W))]
public struct B : IComponentData
{
   public int Value;
}
```

>请注意，不要将WriteGroup的目标（在上面的示例中为W结构）添加到其自己的WriteGroup中

## 启用 WriteGroup filtering
要启用WriteGroup筛选，请在用于创建查询的`EntityQueryDesc`对象上设置FilterWriteGroups标志：
```CS
public class AddingSystem : JobComponentSystem
{
   private EntityQuery m_Query;

   protected override void OnCreate()
   {
       var queryDescription = new EntityQueryDesc
       {
           All = new ComponentType[] {typeof(A), typeof(B)},
           Options = EntityQueryOptions.FilterWriteGroup
       };
       m_Query = GetEntityQuery(queryDescription);
   }
   // Define Job and schedule...
}
```

## 使用 WriteGroups 覆盖 其他系统
如果一个系统为要写入的组件定义了WriteGroups，则可以覆盖该系统并使用自己的系统写入这些组件。

要覆盖该系统，请将您自己的组件添加到该系统定义的WriteGroup中。由于WriteGroup筛选会排除WriteGroup中查询未明确要求的任何组件，因此具有你的组件的任何实体都将被另一个系统忽略。

例如，如果你想通过指定旋转的角度和轴来设置实体的方向，则可以创建一个组件和一个系统，以将角度和轴的值转换为四元数并将其写入Unity.Transforms.Rotation组件。为了防止Unity.Transforms系统更新Rotation组件，除了Rotation组件，无论你拥有其他什么组件，，都可以将它放入Rotation WriteGroup中：

组件部分
```CS
using System;
using Unity.Collections;
using Unity.Entities;
using Unity.Transforms;
using Unity.Mathematics;

[Serializable]
[WriteGroup(typeof(Rotation))]
public struct RotationAngleAxis : IComponentData
{
   public float Angle;
   public float3 Axis;
}
```

你自己的系统，如
```CS
//You can then update any entities containing RotationAngleAxis without contention:
using Unity.Burst;
using Unity.Entities;
using Unity.Jobs;
using Unity.Collections;
using Unity.Mathematics;
using Unity.Transforms;

public class RotationAngleAxisSystem : JobComponentSystem
{

   [BurstCompile]
   struct RotationAngleAxisSystemJob : IJobForEach<RotationAngleAxis, Rotation>
   {
       public void Execute([ReadOnly] ref RotationAngleAxis source, ref Rotation destination)
       {
           destination.Value = quaternion.AxisAngle(math.normalize(source.Axis), source.Angle);
       }
   }

   protected override JobHandle OnUpdate(JobHandle inputDependencies)
   {
       var job = new RotationAngleAxisSystemJob();
       return job.Schedule(this, inputDependencies);
   }
}
```

## 使用WriteGroups扩展另一个系统
如果要扩展另一个系统而不是仅覆盖另一个系统，并且进一步希望允许将来的系统可以覆盖或扩展您的系统，则可以在自己的系统上启用WriteGroup筛选。但是，执行此操作时，默认情况下，任何一个系统都不会处理组件的组合。您必须显式查询和处理每个组合。

作为示例，让我们回到前面描述的AddingSystem示例，该示例定义了一个WriteGroup，其包含指向组件W的组件A和B。

如果仅向WriteGroup添加一个称为C的新组件，则，知道C的系统可以查询包含C的实体，而这些实体是否具有组件A或B则无关紧要。但是，如果新的系统还启用了 WriteGroup筛选，就不再适用了。因为如果查询仅需要组件C，则WriteGroup将排除具有A或B的任何实体。相反，你显式的查询每种有意义的组件组合。（你可以在适当的时候适用查询的`All`，或`Any`子句）
```CS
var query = new EntityQueryDesc
{
   All = new ComponentType[] {ComponentType.ReadOnly<C>(), ComponentType.ReadWrite<W>()},
   Any = new ComponentType[] {ComponentType.ReadOnly<A>(), ComponentType.ReadOnly<B>()},
   Options = EntityQueryOptions.FilterWriteGroup
};
```

对于任何实体，如果它拥有WriteGroup的组件组合，且这些组件没有被明确指定处理，则该实体不会被系统任何写入WriterGroup的目标（以及WriteGroups上的筛选器）。
然而，在程序中创建此类实体首先就很可能是逻辑上的错误。（因为拥有同一个WriteGroup的上组件组合，却没有特别意义，即没有相关系统对其进行处理，也就和普通组件没什么区别，就要考虑是否需要使用WriteGroup）
