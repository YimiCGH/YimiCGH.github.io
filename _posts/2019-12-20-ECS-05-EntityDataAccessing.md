---
layout: post
title: 'Unity ECS 研究 05 —— 实体数据访问'
categories:
      - 翻译
tags:
  - ECS
  - Unity
last_modified_at: 2019-12-20T23:00:00-23:00
---
{% include toc %}
---
## 访问实体数据
遍历数据是实现ECS系统时，最常见的执行任务之一。ECS系统通常处理一组实体，从一个或多个组件读取数据，执行计算，然后写入另一个组件。

通常，遍历实体最有效的方法是在可并行处理的Job中，该Job按照顺序处理组件。这利用了所有可用内核的处理能力和数据局部性来避免CPU高速缓存未命中。

ECS API 提供了多种遍历数据的方法，每种方法都有其自身的性能含义和限制。
- [JobComponentSystem Entities.ForEach](#1)：最简单有效的方法来逐个实体地处理组件数据
- [IJobForEach](#2)：使用Job 结构来有效地遍历实体。(IJobForEach等同于在JobComponentSystem中使用 Entities.ForEach，但需要编写更多代码)
- [IJobForEachWithEntity](#3) ：比IJobForEach稍微复杂点，使你可以访问要处理的实体的handle和数组索引
- [IJobChunk](#5)：遍历包含匹配实体的符合内存块。你的 Job Execute()函数可以使用for遍历每个块内的Elements。你可以将IJobChunk用于比IJobForEach支持的更复杂的情况，同时保持最高的效率
- [ComponentSystem](#4)：ComponentSystem提供了Entities.ForEach函数来帮助你遍历实体。但是，ForEach在主线程上运行，因此，你应该将ComponentSystem实现于无论如何都必须在主线程上执行的任务
- 手动遍历：如果前面的方法不够用，你可以手动遍历实体或块。例如，你可以获取一个NativeArray，其中包含要处理的实体或实体块，并使用Job(例如`IJobParallelFor`)对其进行迭代。

EntityQuery 类提供了一种构造数据视图的方法，该视图仅包含给定算法或处理所需的特定数据。上面列表中的许多遍历方法都显示或在内部使用了EntityQuery。


<a name="1"></a>
## JobComponentSystem lambda 函数

`JobComponentSystem` lambda 函数提供了一种简洁的方法基于实体、实体的组件或native 容器，来定义和执行你的算法。

`JobComponentSystem`支持两种类型的lambda函数：
- `JobComponentSystem.Entities.ForEach(lambda)`：对由实体查询（由Entities.ForEach 选项和 lambda 参数定义）选择的所有实体执行lambda函数。
- `JobComponentSystem.Job.WithCode(lambda)`：作为Job执行的一次性lambda函数。

要执行Job lambda函数，请使用 `ForEach()` 或`WithCode()`定义lambda，然后使用`Schedule()` 来安排Job，或者通过`Run()`在主线程上立即执行它。无论你使用 `ForEach()` 还是`WithCode()`，都可以使用在这些对象上定义的其他方法来设置各种Job选项和参数。

### lambda Example
**1. Entities.ForEach**
以下示例说明了一个简单的`JobComponentSystem`，它使用Entities.ForEach读取一个组件（本例中的Velocity）并写入另一个组件（Tanslation）:
```CSharp
class ApplyVelocitySystem : JobComponentSystem
{
    protected override JobHandle OnUpdate(JobHandle inputDependencies)
    {
        var jobHandle = Entities
            .ForEach((ref Translation translation,
                      in Velocity velocity) =>
            {
                translation.Value += velocity.Value;
            })
            .Schedule(inputDependencies);

        return jobHandle;
    }
}
```

>注意：
在ForEach lambda 函数的参数上使用关键字 `ref`和`in`。使用`ref`表示要写入的组件，使用`in`表示仅读取的组件。将组件标记为只读可以帮助job调度程序更加有效的执行jobs。

**2. Job.WithCode**

`Job.WithCode`lambda函数的参数列表不接受任何参数

以下示例简单展示了两个 `Job.WithCode()` lambda函数，一个用随机数填充 native 数组，另一个将这些数字累加起来：

```CSharp
public class RandomSumJob : JobComponentSystem
{
    private uint seed = 1;

    protected override JobHandle OnUpdate(JobHandle inputDeps)
    {
        Random randomGen = new Random(seed++);
        NativeArray<float> randomNumbers
            = new NativeArray<float>(500, Allocator.TempJob);

        JobHandle generateNumbers = Job.WithCode(() =>
        {
            for (int i = 0; i < randomNumbers.Length; i++)
            {
                randomNumbers[i] = randomGen.NextFloat();
            }
        }).Schedule(inputDeps);


        NativeArray<float> result
            = new NativeArray<float>(1, Allocator.TempJob);

        JobHandle sumNumbers = Job.WithCode(() =>
        {
            for (int i = 0; i < randomNumbers.Length; i++)
            {
                result[0] += randomNumbers[i];
            }
        }).Schedule(generateNumbers);

        sumNumbers.Complete();
        UnityEngine.Debug.Log("The sum of "
                              + randomNumbers.Length + " numbers is " + result[0]);

        randomNumbers.Dispose();
        result.Dispose();

        return sumNumbers;
    }
}
```
在实际应用中，第一个Job 可能会从并行jobs中的一组实体组件里计算出中间结果，而第二个Job会结合这些结果来计算解决方案。

### Entities.ForEach 实体查询

由`Entities.ForEach`lambda 处理的实体和块 由实体查询来筛选，该查询在创建`JobComponentSystem`时隐式创建。（使用`WithStoreEntityQueryInField(ref EntityQuery)` 可以访问该隐式`EntityQuery` 对象）

该查询是通过将声明lambda函数的参数 与  使用 `WithAll<T>` ， `WithAny<T>`，`WithNone<T>`函数显示添加的组件类型 合并组成的。你也可以使用其他Entities函数来设置查询选项。与查询相关的 Entities 函数有：
- `WithAll<T>`：实体必须具有所有这些组件类型（除了在lambda参数列表中找到的所有组件类型）
- `WithAny<T,U>`：实体必须具有一个或多个这些组件类型。注意，允许使用`WithAny`指定单个组件类型；但是，由于实体必须具有查询中这些可选组件类型中的其中一种或多种，一次，对于单个类型使用`WithAny`等效于放入`WithAll`语句中。
- `WithNone<T>`：实体不能具有这些组件类型中的任何一个
- `WithChangeFilter<T>`：仅选择自上次JobComponentSystem更新以来，块中发生改变的指定类型的组件
- `WithSharedComponentFilter`：仅选择共享组件具有指定值的块
- `WithStoreEntityQueryInField`：将由Entities.ForEach生成的EntityQuery对象存储在JobComponentSystem的EntityQuery字段中。你可以将此EntityQuery对象用于存储诸如获取由查询选择的实体的数量之类的目的。注意，在创建JobComponentSystem时，此函数将EntityQuery实例分配给你的字段。这意味着，你可以在首次执行lambda函数自之前使用查询。

>重点：
不要在lambda的参数列表中使用`WithAny<T,U>`或`WithNone<T>`的查询中用到的组件类型。你添加到lambda函数参数列表中的所有组件都会自动添加到实体查询的WithAll列表中；将组件同时添加到 WithAll列表，WithAny 或WithNone列表 会产生一个不合逻辑的查询。

**1. Entity query example**
下面示例选择具有 Destination，Source 和 LocalToWorld组件的实体；并且至少包含 Rotation,Translation,或Scale中的其中一个；但是不能包含LocalToParent组件
```CSharp
return Entities.WithAll<LocalToWorld>()
    .WithAny<Rotation, Translation, Scale>()
    .WithNone<LocalToParent>()
    .ForEach((ref Destination outputData,
        in Source inputData) =>
    {
        /* do some work */
    })
    .Schedule(inputDeps);
```
在此示例中，只能在lambda函数中访问Destination 和 Source组件，因为它们在参数列表的组件中是唯一的。（如果需要在lambda函数中也能访问LocalToWorld组件，那么只需把`WithAll<LocalToWorld>`去掉，把LocalToWorld 添加到参数列表中就行了）

**2. 访问EntityQuery对象 example**
下面示例说明如何访问为Entities.ForEach结构 隐式创建的EntityQuery对象。本例中，使用EntityQuery对象来调用`CalculateEntityCount()`方法。该示例使用此计数来创建一个native数组，该数组具有足够的空间来为查询选择的每一个实体存储一个值：

```CSharp
private EntityQuery query;
protected override JobHandle OnUpdate(JobHandle inputDeps)
{
    int dataCount = query.CalculateEntityCount();
    NativeArray<float> dataSquared
        = new NativeArray<float>(dataCount, Allocator.Temp);

    JobHandle GetSquaredValues = Entities
        .WithStoreEntityQueryInField(ref query)
        .ForEach((int entityInQueryIndex, in Data data) =>
            {
                dataSquared[entityInQueryIndex] = data.Value * data.Value;
            })
        .Schedule(inputDeps);

    return Job
        .WithCode(() =>
        {
            //Use dataSquared array...
            var v = dataSquared[dataSquared.Length -1];
        })
        .WithDeallocateOnJobCompletion(dataSquared)
        .Schedule(GetSquaredValues);
}
```

#### 可选组件
你无法创建指定可选组件的查询（即使用 `WithAny<T,U>`），也无法在lambda函数中访问这些组件。如果需要读取或写入可选组件，则可以将Entities.ForEach结构拆分为多个Job。每个可选组件组合作为一个Job。例如，你有两个可选组件，则需要三个ForEach结构：一个包含第一个可选组件，一个包含第二个可选组件，一个包含两个组件。另一种选择是使用`IJobChunk`逐块进行遍历。

#### 筛选变更组件
如果你只想在实体的某个组件自JobComponentSystem上次更新以来发生变化时,处理该组件，你可以使用`WithChangeFilter<T>`来启用变更筛选。变更过滤器使用的组件类型必须在lambda函数的参数列表中，或者必须是`WithAll<T>`语句的一部分。

```CSharp
return Entities
    .WithChangeFilter<Source>()
    .ForEach((ref Destination outputData,
        in Source inputData) =>
    {
        /* Do work */
    })
    .Schedule(inputDeps);
```
实体查询最多支持两种组件类型的变更过滤。

>注意：
变更过滤应用于块级别。如果任何代码通过写访问权限访问了块中的某个组件，则该块中的这个组件类型就会标记为已更改（即使该代码实际上并没有更改任何数据）。

#### 共享组件过滤
具有共享组件的实体会和其他具有相同共享组件值的实体放到同一个块中。你可以使用`WithSharedComponentFilter()`函数选择具有特定共享组件值的实体组。

下面的例子选择按Cohort（同类群组） ISharedComponentData 分组的实体。lambda函数根据实体的Cohort设置 DisplayColor IComponentData 组件：
```CSharp
public class ColorCycleJob : JobComponentSystem
{
    protected override JobHandle OnUpdate(JobHandle inputDeps)
    {
        List<Cohort> cohorts = new List<Cohort>();
        EntityManager.GetAllUniqueSharedComponentData<Cohort>(cohorts);
        NativeList<JobHandle> dependencies
            = new NativeList<JobHandle>();

        foreach (Cohort cohort in cohorts)
        {
            DisplayColor newColor = ColorTable.GetNextColor(cohort.Value);
            JobHandle thisJobHandle
                = Entities.WithSharedComponentFilter(cohort)
                    .ForEach((ref DisplayColor color) => { color = newColor; })
                    .Schedule(inputDeps);
            dependencies.Add(thisJobHandle);
        }

        return JobHandle.CombineDependencies(dependencies);
    }
}
```
该示例使用`EntityManager`来获取所有唯一的 cohort 值（即该共享组件的现有的所有设置情况）。然后，它为每个cohort安排一个lambda job，并把新的颜色作为捕获变量传递给lambda函数。由于所有的job都在不同块上运行，因此它们可以并行的运行（它们都通过将inputDeps对象传递给系统的`OnUpdate()`函数来进行调度）。由于系统调度了多个独立的job，因此它还将独立的job 句柄组合成一个，并作为`OnUpdate()`的返回值

### lambda 参数
当你要定义和`Entities.ForEach`一起使用的lambda函数时，可以声明JobComponentSystem执行该函数时用于传递当前实体（或块）的有关信息（`Job.WithCode` lambda函数不接受任何参数）

你可以最多将八个参数传递给`Entities.ForEach`。参数必须按一下顺序分组：
```
1. 首先是 按值传递参数（无参数修饰符）
2. 然后是 可写参数（'ref'参数修饰符）
3. 最后是 只读参数('in'参数修饰符)
```
所有组件都应该使用`ref`或`in`参数修饰符关键字。

如果你的函数不遵循这些规则，则编译器会提供下面错误提示：
```
error CS1593: Delegate 'Invalid_ForEach_Signature_See_ForEach_Documentation_For_Rules_And_Restrictions' does not take N arguments
```

>注意：
即使问题是顺序的问题，错误消息也只会提示是参数数目的问题

#### 组件参数
要访问与实体相关的组件，必须将该组件类型作为参数传递给 Entities.ForEach lambda 函数（除非你要遍历的是块而不是实体）。编译器会自动将彻底给函数的所有组件作为必须组件添加到实体查询中。

要更新组件的值，必须在参数列表中使用`ref`关键字来将其引用传递给lambda函数。（没有`ref`关键字，任何修改都只是对该组件的副本上进行的，因为它是通过值传递进来的。）

>注意：
使用`ref`意味着即使lambda函数实际上并没有对值做任何修改，当前块中该组件也会被标记为已更改。为了提高效率，请始终将lambda函数未修改的组件指定为只读。要将传递给lambda函数的组件指定为只读，只需要在参数列表上使用`in`关键字

以下示例将Source组件参数作为只读传递给job，并将Destination组件参数作为可写传递给job：
```CSharp
return Entities.ForEach(
        (ref Destination outputData,
            in Source inputData) =>
        {
            outputData.Value = inputData.Value;
        })
    .Schedule(inputDeps);
```

注意：
当前，你不能将块组件程度给Entities.ForEach lambda函数。对于动态缓冲区，请使用`DynamicBuffer<T>`而不是存储在缓存中的 Component Type,如下面的例子（使用的是 `DynamicBuffer<IntBufferData>`，而不是 IntBufferData）：

```CSharp
public class BufferSum : JobComponentSystem
{
    private EntityQuery query;

    //Schedules the two jobs with a dependency between them
    protected override JobHandle OnUpdate(JobHandle inputDeps)
    {
        //The query variable can be accessed here because we are
        //using WithStoreEntityQueryInField(query) in the entities.ForEach below
        int entitiesInQuery = query.CalculateEntityCount();

        //Create a native array to hold the intermediate sums
        //(one element per entity)
        NativeArray<int> intermediateSums
            = new NativeArray<int>(entitiesInQuery, Allocator.TempJob);

        //Schedule the first job to add all the buffer elements
        JobHandle bufferSumJob = Entities
            .ForEach((int entityInQueryIndex, in DynamicBuffer<IntBufferData> buffer) =>
            {
                for (int i = 0; i < buffer.Length; i++)
                {
                    intermediateSums[entityInQueryIndex] += buffer[i].Value;
                }
            })
            .WithStoreEntityQueryInField(ref query)
            .WithName("IntermediateSums")
            .Schedule(inputDeps);

        //Schedule the second job, which depends on the first
        JobHandle finalSumJob = Job
            .WithCode(() =>
            {
                int result = 0;
                for (int i = 0; i < intermediateSums.Length; i++)
                {
                    result += intermediateSums[i];
                }
                //Not burst compatible:
                Debug.Log("Final sum is " + result);
            })
            .WithDeallocateOnJobCompletion(intermediateSums)
            .WithoutBurst()
            .WithName("FinalSum")
            .Schedule(bufferSumJob);

        return finalSumJob;
    }
}
```

#### 特殊命名参数
除了组件类型之外，你还可以将以下特殊的命名参数传递给Entities.ForEach lambda函数，这些参数是根据job正在处理的实体分配的值。
- `Entity entity`：当前实体的Entity实例。（可以将参数随意命名，只要类型为Entity）
- `int entityInQueryIndex`：该实体在查询所选择的实体列表中的索引。当你需要使用一个native array 来为每一个实体填充一个唯一值时，请使用该实体的索引。你可以将`entityInQueryIndex`作为该数组中的索引，`entityInQueryIndex`也应该用作将命令添加到并发`EntityCommandBuffer`的jobIndex。
- `int nativeThreadIndex`：执行当前的lambda函数遍历 的线程的唯一索引。使用`Run()`执行lambda函数时，`nativeThreadIndex`始终为零。

### 捕获变量
你可以捕获`Entities.ForEach` 和 `Job.WithCode` lambda函数的局部变量。当你使用job执行函数时（通过调用`Schedule()`而不是`Run()`），对捕获变量及其使用方式有一些限制：

只能捕获native 容器类型和 `blittable `类型。job只能写入native 容器 类型的捕获变量。（要返回单个只，可以通过创建只有一个元素的native容器）

你可以使用以下函数来将修饰符和特性应用到捕获变量上：
- `WithReadOnly(myvar)`：限制对变量的访问为只读。
- `WithDeallocateOnJobCompletion(myvar)`：job完成后取消native容器的分配，参阅[DeallocateOnJobCompletionAttribute](https://docs.unity3d.com/ScriptReference/Unity.Collections.DeallocateOnJobCompletionAttribute.html)。
- `WithNativeDisableParallelForRestriction(myvar)`：允许多个线程访问相同的可写native容器。仅当每个线程仅访问容器中自己的唯一范围元素时（和其它无线程冲突元素），并行访问才是安全的。如果多个线程访问同一个元素，则会产生竞争条件，其访问时间先后会影响结果。参阅[NativeDisableParallelForRestriction](https://docs.unity3d.com/ScriptReference/Unity.Collections.NativeDisableParallelForRestrictionAttribute.html)
- `WithNativeDisableContainerSafetyRestriction(myvar)`：禁用正常的安全限制，该限制是为了防止危险的访问native容器。不明智地禁用安全限制可能会导致竞争条件，细微的错误以及应用程序崩溃。参阅[NativeDisableContainerSafetyRestrictionAttribute](https://docs.unity3d.com/ScriptReference/Unity.Collections.LowLevel.Unsafe.NativeDisableContainerSafetyRestrictionAttribute.html)
- `WithNativeDisableUnsafePtrRestrictionAttribute(myvar)`：允许你使用native容器提供的不安全指针。错误的使用指针可能导致细微的错误，不稳定以及应用程序的崩溃。参阅[NativeDisableUnsafePtrRestrictionAttribute](https://docs.unity3d.com/ScriptReference/Unity.Collections.LowLevel.Unsafe.NativeDisableUnsafePtrRestrictionAttribute.html)

### Job 选项
你可以对`Entities.ForEach` 和 `Job.WithCode` lambda 函数使用以下方法：
- `JobHandle Schedule(JobHandle)`：安排lambda函数作为job执行：
  - `Entities.ForEach`：job 在 并行后台，job线程上执行lambda函数。每个job遍历由ForEach 查询选择的块中的实体。(job自身在单个块中处理实体。)
  - `Job.WithCode`：job在后台job线程上执行lambda函数的单个实例。
- `void Run()`：在主线程上同步执行lambda函数：
  - `Entities.ForEach`：对于由ForEach 查询选择的块中的每个实体，执行一次lambda函数。注意，由于lambda函数不能作为job运行，因此Run()不会使用JobHandle参数，也不返回JobHandle。
  - `Job.WithCode`：执行lambda函数一次。
- `WithBurst(FloatMode, FloatPrecision, bool)`：设置Burst编译器的选项：
  - floatMode ：设置浮点数数学优化模式。快速(`Fast`)模式执行速度更快，但比严格(`Strict`)模式尝试更大的浮点错误,默认为严格模式。参阅[Burst FloatMode](https://docs.unity3d.com/Packages/com.unity.burst@1.1/api/Unity.Burst.FloatMode.html)
  - floatPrecision ：设置浮点数精度。参阅[Burst FloatPrecision](https://docs.unity3d.com/Packages/com.unity.burst@latest?subfolder=/api/Unity.Burst.FloatPrecision.html)
  - synchronousCompilation：立即编译该函数，而不是安排到以后编译。
- `WithoutBurst()`：禁用Burst编译。当你使用的lambda函数包含Burst不支持的代码时，请使用此函数。
- `WithStructuralChanges()`：在主线程上执行lambda函数并禁用Burst，以便你可以在函数内对实体数据进行结构更改。为了获得更好的性能，请使用`EntityCommandBuffer`来代替。
- `WithName(string)`：将指定字符串分配为生成的job类的名称。分配名称是可选的，但是有助于在调试和分析时帮助识别。

#### Job 依赖
传递给JobComponentSystem.OnUpdate()方法的JobHandle对象封装了到目前为止，在上一帧已经更新完成的，由JobComponentSystem实例声明的所有相关组件的可读写job依赖项。当你将来自之前的系统的输入依赖传递给Schedule方法时，ECS会确保写入组件数据和当前lambda函数访问组件一样的job都会事先完成。当你调用`Run()`时，lambda函数在主线程执行，因此，任何由先前系统安排的job都会马上完成。

同样的，你的`OnUpdate()`函数必须通过JobHandle返回它的依赖项给其它后续系统。如果你的Update函数构造了一个job，则可以返回`Schedule()`提供的JobHandle。如果你的Update函数构造了多个jobs,则可以通过将一个返回的JobHandle传递给下一个job的`Schedule()`方法来连接各个依赖关系；或者，如果这些jobs彼此不依赖，则可以使用[JobHandle.CombineDependencies()](https://docs.unity3d.com/ScriptReference/Unity.Jobs.JobHandle.CombineDependencies.html)。

```CSharp
// Schedule 3 jobs, job a and b can run in parallel to each other,
// job c will only run once both jobA and jobB has completed

// Schedule job a
var jobA = new MyJob(...);
var jobAHandle = jobA.Schedule();

// Schedule job b
var jobB = new MyJob(...);
var jobBHandle = jobB.Schedule();

// For Job c, combine dependencies of job a and b
// Then use that for scheduling the next job
var jobC = new DependentJob(...);
var dependency = JobHandle.CombineDependencies(jobAHandle, jobBHandle);
jobC.Schedule(dependency);
```

>注意：
JobHandle 仅包含对组件数据的依赖关系，不包含native 容器。如果你有一个系统或job读取一个由其它系统或job填充的native容器，则必须手动管理依赖性。一种实现方式是，提供一种方法或属性，该方法或属性允许生产系统添加一个JobHandle作为消费系统的依赖项。（有关此技术的实例，参考EntityCommandBufferSystem的 [AddProducerFor()]()方法）

### 将Entities.ForEach与EntityCommandBuffer一起使用
你无法对Job中的实体进行结构更改，包括创建或销毁实体，添加或删除组件。不过，你可以使用实体命令缓冲区将结构更改推迟到帧的下一个点。默认的ECS系统组设置在标准系统组的开头和末尾各提供了一个实体命令缓存系统。通常，你应该选择在你其他所有依赖该结构变化的系统之前运行的最后一个实体命令缓存系统。

例如，如果你在simulation 系统组中创建实体，并希望在同一帧中呈现这些实体，则在创建实体时，可以使用由`EndSimulationEntityCommandBufferSystem`创建的实体命令缓存。

要创建实体命令缓存，请存储对要使用的实体命令缓存系统的引用。在`OnUpdate()`函数中，使用该引用创建用于当前帧的EntityCommandBuffer实例。（你必须为每次更新创建一个新的实体命令缓存。）

下面的例子说明了如何创建实体命令缓冲，在本例中，该实体缓存是从`EndSimulationEntityCommandBufferSystem`中获得的：

```CSharp
public class MyJobSystem : JobComponentSystem
{
    private EndSimulationEntityCommandBufferSystem commandBufferSystem;

    protected override void OnCreate()
    {
        commandBufferSystem = World
            .DefaultGameObjectInjectionWorld
            .GetOrCreateSystem<EndSimulationEntityCommandBufferSystem>();
    }

    protected override JobHandle OnUpdate(JobHandle inputDeps)
    {
        EntityCommandBuffer.Concurrent commandBuffer
            = commandBufferSystem.CreateCommandBuffer().ToConcurrent();

        //.. The rest of the job system code
        return inputDeps;
    }
}
```

由于 `Entities.ForEach.Schedule() `创建的是一个并行 job，你必须使用实体命令缓存的并行接口，即`EntityCommandBuffer.Concurrent`

**Entites.ForEach lambda with entity command buffer example**
以下示例说明了在实现简单粒子系统的JobComponentSystem中使用实体命令缓存：
```CSharp
// ParticleSpawner.cs
using Unity.Entities;
using Unity.Jobs;
using Unity.Mathematics;
using Unity.Transforms;

public struct Velocity : IComponentData
{
    public float3 Value;
}

public struct TimeToLive : IComponentData
{
    public float LifeLeft;
}

public class ParticleSpawner : JobComponentSystem
{
    private EndSimulationEntityCommandBufferSystem commandBufferSystem;

    protected override void OnCreate()
    {
        commandBufferSystem = World
            .DefaultGameObjectInjectionWorld
            .GetOrCreateSystem<EndSimulationEntityCommandBufferSystem>();
    }

    protected override JobHandle OnUpdate(JobHandle inputDeps)
    {
        EntityCommandBuffer.Concurrent commandBufferCreate
            = commandBufferSystem.CreateCommandBuffer().ToConcurrent();
        EntityCommandBuffer.Concurrent commandBufferCull
            = commandBufferSystem.CreateCommandBuffer().ToConcurrent();

        float dt = Time.DeltaTime;
        Random rnd = new Random();
        rnd.InitState((uint) (dt * 100000));


        JobHandle spawnJobHandle = Entities
            .ForEach((int entityInQueryIndex,
                      in SpawnParticles spawn,
                      in LocalToWorld center) =>
            {
                int spawnCount = spawn.Rate;
                for (int i = 0; i < spawnCount; i++)
                {
                    Entity spawnedEntity = commandBufferCreate
                        .Instantiate(entityInQueryIndex,
                                     spawn.ParticlePrefab);

                    LocalToWorld spawnedCenter = center;
                    Translation spawnedOffset = new Translation()
                    {
                        Value = center.Position +
                                rnd.NextFloat3(-spawn.Offset, spawn.Offset)
                    };
                    Velocity spawnedVelocity = new Velocity()
                    {
                        Value = rnd.NextFloat3(-spawn.MaxVelocity, spawn.MaxVelocity)
                    };
                    TimeToLive spawnedLife = new TimeToLive()
                    {
                        LifeLeft = spawn.Lifetime
                    };

                    commandBufferCreate.SetComponent(entityInQueryIndex,
                                                     spawnedEntity,
                                                     spawnedCenter);
                    commandBufferCreate.SetComponent(entityInQueryIndex,
                                                     spawnedEntity,
                                                     spawnedOffset);
                    commandBufferCreate.AddComponent(entityInQueryIndex,
                                                     spawnedEntity,
                                                     spawnedVelocity);
                    commandBufferCreate.AddComponent(entityInQueryIndex,
                                                     spawnedEntity,
                                                     spawnedLife);
                }
            })
            .WithName("ParticleSpawning")
            .Schedule(inputDeps);

        JobHandle MoveJobHandle = Entities
            .ForEach((ref Translation translation, in Velocity velocity) =>
            {
                translation = new Translation()
                {
                    Value = translation.Value + velocity.Value * dt
                };
            })
            .WithName("MoveParticles")
            .Schedule(spawnJobHandle);

        JobHandle cullJobHandle = Entities
            .ForEach((Entity entity, int entityInQueryIndex, ref TimeToLive life) =>
            {
                life.LifeLeft -= dt;
                if (life.LifeLeft < 0)
                    commandBufferCull.DestroyEntity(entityInQueryIndex, entity);
            })
            .WithName("CullOldEntities")
            .Schedule(inputDeps);

        JobHandle finalDependencies
            = JobHandle.CombineDependencies(MoveJobHandle, cullJobHandle);

        commandBufferSystem.AddJobHandleForProducer(spawnJobHandle);
        commandBufferSystem.AddJobHandleForProducer(cullJobHandle);

        return finalDependencies;
    }
}
```

```CSharp
// SpawnParticles.cs
using Unity.Entities;
using Unity.Mathematics;

[GenerateAuthoringComponent]
public struct SpawnParticles : IComponentData
{
    public Entity ParticlePrefab;
    public int Rate;
    public float3 Offset;
    public float3 MaxVelocity;
    public float Lifetime;
}
```

### 实现说明
`Entities.ForEach` 和 `Job.WithCode` 使用编译器扩展 把你编写的代码转换为更加高效的基于Job的C#代码，本质上，编写 `Entities.ForEach` 和 `Job.WithCode`结构时，你是在描述要执行的工作，并且编译器扩展会生成所需代码以实现此目的。通常，这种转换对你应该是透明的，请注意以下几点：
- lambda函数的性能缺点（例如捕获变量时额外的托管内存分配）不适用
- IDE中的代码完成可能未列出Entities和Job对象方法的正确参数。
- 您可能会在警告，错误消息和IL代码反汇编之类的位置看到生成的类名。
- 当您使用`WithStoreEntityQueryInField（ref query）`时，编译器扩展会在系统的`OnCreate（）`方法之前为查询字段分配一个值。
这意味着您可以在`Entities.ForEach` lambda函数首次运行之前访问该字段引用的EntityQuery对象。

<a name="2"></a>
## 使用 IJobForEach
你可以在JobComponentSystem中定义IJobForEach job 以读取和写入组件数据。

运行job时，ECS框架会找到具有所需组件的所有实体，并为每个实体调用job 的`Execute()`函数。数据按照在内存中的排列顺序进行处理，并且Job并行运行，因此`IJobForEach`结合了简单性和效率。

下面的例子显示了一个使用 `IJobForEach`的简单系统。job读取RotationSpeed组件，然后写入 RotationQuaternion 组件。
```CSharp
public class RotationSpeedSystem : JobComponentSystem
{
   // Use the [BurstCompile] attribute to compile a job with Burst.
   [BurstCompile]
   struct RotationSpeedJob : IJobForEach<RotationQuaternion, RotationSpeed>
   {
       public float DeltaTime;
       // The [ReadOnly] attribute tells the job scheduler that this job will not write to rotSpeed
       public void Execute(ref RotationQuaternion rotationQuaternion,
                           [ReadOnly] ref RotationSpeed rotSpeed)
       {
           // Rotate something about its up vector at the speed given by RotationSpeed.  
           rotationQuaternion.Value
               = math.mul(math.normalize(rotationQuaternion.Value),
                          quaternion.AxisAngle(
                              math.up(),
                              rotSpeed.RadiansPerSecond * DeltaTime
                          )
                 );
       }
   }

// OnUpdate runs on the main thread. Any previously scheduled jobs
// reading/writing from Rotation or writing to RotationSpeed
// will automatically be included in the inputDependencies.
protected override JobHandle OnUpdate(JobHandle inputDependencies)
   {
       var job = new RotationSpeedJob()
       {
           DeltaTime = Time.deltaTime
       };
       return job.Schedule(this, inputDependencies);
   }
}
```
这个例子基于GitHub上的 [ECS Samples](https://github.com/Unity-Technologies/EntityComponentSystemSamples) 仓库的HelloCube IJobForEach。

IJobForEach 批量处理存储在同一块的所有实体。当一组实体跨越多个块时，job将并行处理每一批实体。通常，按块遍历一组实体是最有效的方法，因为它可以防止多个线程尝试访问相同的内存块。但是，如果要在少量的实体上运行非常消耗的处理，则IJobForEach可能无法提供最佳性能，因为它无法在每个实体并行上并行运行该过程。这种情况下，你可以使用[IJobParallelFor](https://docs.unity3d.com/ScriptReference/Unity.Jobs.IJobParallelFor.html)，它可以让你控制批处理大小和工作窃取。参考[手动遍历](#6)

### 定义IJobForEach 签名
IJobForEach结构的签名空识别系统在哪些组件上运行：
```
struct RotationSpeedJob : IJobForEach<RotationQuaternion, RotationSpeed>
```
你还可以使用以下特性来修改job选择的实体：
- [ExcludeComponent(typeof(T)] ：排除其原型包含类型T组件的实体。
- [RequireComponentTag(typeof(T)]：仅包含原型中包含类型T的组件的实体。当系统不读写该组件数据，仅用来标识，获取实体时，请使用此特性。

例如，以下job定义了选择原型具有Gravity，RotationQuaternion,RotationSpeed组件,但不包含Frozen组件的实体：
```CSharp
[ExcludeComponent(typeof(Frozen))]
[RequireComponentTag(typeof(Gravity))]
[BurstCompile]
struct RotationSpeedJob : IJobForEach<RotationQuaternion, RotationSpeed>{
  //...
}
```

如果你需要更复杂的查询来选择要操作的实体，则可以使用`IJobChunk` job来代替 `IJobForEach`

### 编写 Execute() 方法
JobComponentSystem为某个合格的实体调用Execute()方法，并传入由`IJobForEach`签名标识的组件。因此，`Execute()`函数的参数必须匹配与你为结构定义的通用参数匹配。

例如，以下`Execute()`方法读取RotationSpeed组件。（读/写 是默认设置，所以不需要添加特性）
```CSharp
public void Execute(ref RotationQuaternion rotationQuaternion,
                    [ReadOnly] ref RotationSpeed rotSpeed){}
```
你可以在函数的参数列表上添加特性，来帮助ECS优化系统：
- [ReadOnly] : 用于只读取，但不写入的组件。
- [WriteOnly] : 用于只写入，但不读取的组件。
- [ChangedFilter] : 只在自系统上一次更新以来该组件的值发生变化的实体上运行此函数。

通过识别只读和只写组件，job 规划程序可以高效的规划job。例如，调度程序不会在同时调度读取该组件的job和写入该组件的job，但如果这两个job都是只读取相同的组件，则调度程序可以并行运行这两个job。

>注意：
为了提高效率，变更过滤器适用于这个实体块，它不跟踪单个实体。如果另一个能够写入该类型组件的job访问来某个块，则ECS框架会任务该块已经更改，并包括该job中的所有实体。否则，ECS框架会完全排除该块中的实体。


<a name="3"></a>
## 使用 IJobForEachWithEntity

实现`IJobForEachWithEntity`接口的job和实现`IJobForEach`的job 的行为大致相同。区别在于 `IJobForEachWithEntity`中的`Execute()`函数签名为你提供了当前实体的Entity对象，以及为组件的扩展的并行数组的索引。

### 使用 Entity 参数
你可以使用Entity对象将命令添加到EntityCommandBuffer。例如，你可以添加命令来添加或删除该实体上的组件，或销毁该实体。为了避免竞争条件，所有的这些操作都不能在直接job内完成。使用命令缓存，你可以在工作现场上执行任何可能超级消耗的计算，同时可以对稍后在主线程上执行的实际插入和删除操作进行排队。

以下系统基于 HelloCube SpawnFromEntity 示例，在job中计算完实体的位置后，使用命令缓存实例化实体：

```CSharp
public class SpawnerSystem : JobComponentSystem
{
   // EndFrameBarrier provides the CommandBuffer
   EndFrameBarrier m_EndFrameBarrier;

   protected override void OnCreate()
   {
       // Cache the EndFrameBarrier in a field, so we don't have to get it every frame
       m_EndFrameBarrier = World.GetOrCreateSystem<EndFrameBarrier>();
   }
   struct SpawnJob : IJobForEachWithEntity<Spawner, LocalToWorld>
   {
       public EntityCommandBuffer CommandBuffer;
       public void Execute(Entity entity, int index, [ReadOnly] ref Spawner spawner,
           [ReadOnly] ref LocalToWorld location)
       {
           for (int x = 0; x < spawner.CountX; x++)
           {
               for (int y = 0; y < spawner.CountY; y++)
               {
                   var __instance __= CommandBuffer.Instantiate(spawner.Prefab);
                   // Place the instantiated in a grid with some noise
                   var position = math.transform(location.Value,
                       new float3(x * 1.3F, noise.cnoise(new float2(x, y) * 0.21F) * 2, y * 1.3F));
                   CommandBuffer.SetComponent(instance, new Translation {Value = position});
               }
           }
           CommandBuffer.DestroyEntity(entity);
       }
   }

   protected override JobHandle OnUpdate(JobHandle inputDeps)
   {
       // Schedule the job that will add Instantiate commands to the EntityCommandBuffer.
       var job = new SpawnJob
       {
           CommandBuffer = m_EndFrameBarrier.CreateCommandBuffer()
       }.ScheduleSingle(this, inputDeps);

       // We need to tell the barrier system which job it needs to complete before it can play back the commands.
       m_EndFrameBarrier.AddJobHandleForProducer(job);

       return job;
   }
}
```

>注意：
例子中使用IJobForEach.ScheduleSingle()，该函数在单个线程上执行job。如果改用Schedule()方法，则系统将使用并行job来处理实体。这种情况下，必须使用 `EntityCommandBuffer.Concurrent`。
有关完整实例，参阅 [ECS Example 仓库](https://github.com/Unity-Technologies/EntityComponentSystemSamples)

### 使用 index 参数
你可以在将命令添加到并发命令缓存时使用index。在运行并行处理实体的jobs时，你可以使用并发命令缓存（concurrent command buffers）。在`IJobForEachWithEntity` job 中，当你使用`Schedule()`方法而不是 上面例子中的 `ScheduleSingle()`方法时，Job System 将并行处理实体。并行命令缓存始终用于并行jobs，以确保线程安全和缓存命令的确定性的执行。

你也可以使用index来引用同一系统中所有jobs中的相同实体。例如，如果你需要多次处理一组实体，并在此过程中收集临时数据，则可以使用index将临时数据插入一个job中的NativeArray 中，然后在后续job中使用该索引访问进行访问。（当然，你必须要把同一个NativeArray 传递给这些Jobs）

<a name="4"></a>
## 使用 ComponentSystem 和 ForEach

你可以使用ComponentSystem来处理数据。ComponentSystem方法在主线程上运行，因此不会利用多个CPU内核。可以在以下的情况下使用ComponentSystems：
- 进行调试或探索性开发时（有时，在主线程上运行代码可以更加容易观察发生了什么。例如你可以记录调试文本并绘制调试图形）
- 当系统需要访问只能在主线程上运行的其它API或与之交互时，，可以帮助你逐渐将游戏系统转换为ECS，而不必从头开始重写所有内容。
- 系统执行的工作量少于创建和调度job的少量开销。
- 需要在遍历时直接对实体进行结构更改（添加/删除组件，销毁实体等）时，与JobComponentSystem不同，ComponentSystem可以在ForEach lambda函数内部修改实体

>重要提示：
进行结构更改会强制完成所有job。该事件成为同步点，可能会导致性能下降，因为系统在等待同步点时无法利用所有可用的CPU内核。
在ComponentSystem中，应该使用更新后的命令缓存。同步点仍会发生，但是所有结构性更改都是成批发生的，因此影响较小。为了获取最大效率，请使用JobComponentSystem和实体命令缓存。当大量创建实体时，你可以使用另一个World创建实体，然后将这些实体转移到主 游戏世界中。

### 使用ForEach 委托遍历
ComponentSystem 提供了一个Entities.ForEach函数，该函数简化了对一组实体进行遍历的任务。在系统的`OnUpdate()`函数中调用ForEach，传入一个lambda函数，该函数将相关组件作为参数，并且在函数主体执行必要的工作。

下面的例子来自 HelloCube ForEach 示例，为具有RotationQuaternion和RotationSpeed组件的所有实体设置了旋转动画：
```CSharp
public class RotationSpeedSystem : ComponentSystem
{
   protected override void OnUpdate()
   {
       Entities.ForEach( (ref RotationSpeed rotationSpeed, ref RotationQuaternion rotation) =>
       {
           var deltaTime = Time.deltaTime;
           rotation.Value = math.mul(math.normalize(rotation.Value),
               quaternion.AxisAngle(math.up(), rotationSpeed.RadiansPerSecond * deltaTime));
       });
   }
 }
```
你最多可用将ForEach lambda函数与六种类型的组件一起使用。

与JobComponentSystem不同，你可以对ComponentSystem的ForEach 内部的现有实体进行结构更改。

例如，如果要从当前转速为0的任何实体中删除RotationSpeed组件，可以使用以下ForEach函数进行更改：

```CSharp
Entities.ForEach( (Entity entity, ref RotationSpeed rotationSpeed, ref RotationQuaternion rotation) =>
{
   var __deltaTime __= Time.deltaTime;
   rotation.Value = math.mul(math.normalize(rotation.Value),
       quaternion.AxisAngle(math.up(), rotationSpeed.RadiansPerSecond * __deltaTime__));

   if(math.abs(rotationSpeed.RadiansPerSecond) <= float.Epsilon) //Speed effectively zero
       EntityManager.RemoveComponent(entity, typeof(RotationSpeed));
});
```
当在ComponentSystem在主线程上运行时，系统可以安全的执行这些命令。

### 实体查询
你可以使用流式查询来约束ForEach lambda，以使其在满足这些约束的一组特定实体上执行。这些查询可以指定是否应在具有任意指定组件，或具有全部指定组件，或不具有任何指定组件 的实体上执行。约束可以链接到一起，对用户来说和C#的LINQ系统非常相似。

>请注意：
作为参数传递给ForEach lambda函数 的任何组件都会自动包含在WithAll集之中，并且，不能再出现在WithAll，WithAny，WithNone查询中。
#### WithAll

`WithAll`约束允许你指定一个实体具有指定的一组组件的全部。例如。对于下面查询，ComponentSystem将对具有 Rotation 和 Scale 组件的所有实体执行lambda函数：

```CSharp
Entities.WithAll<Rotation, Scale>()
.ForEach( (Entity e) =>
{
    // do stuff
});
```

`WithAll`用于 那些必须存在于实体上，不需要读或写的组件（对于需要访问的组件，可以作为ForEach lambda函数的参数）.

如：
```CSharp
Entities.WithAll<SpinningTag>()
.ForEach( (Entity e, ref Rotation r) =>
{
    // do stuff
});
```

#### WithAny

`WithAny` 用于指定实体必须至少拥有指定的一组组件中的一个。下面的例子中，`ComponentSystem`对同时具有Rotation 和 Scale ，以及具有RenderDataA或RenderDataB(或两个都有)的实体执行lambda函数。
```CSharp
Entities.WithAll<Rotation, Scale>()
.WithAny<RenderDataA, RenderDataB>()
.ForEach( (Entity e) =>
{
    // do stuff
});
```

>注意：
无法知道实体上存在`WithAny`集合中的哪一个组件。如果需要根据这些组件的组合方式对实体进行区别对待，建议为每种情况创建一个特定的查询，或者将`JobComponentSystem`与`IJobChunk`一起使用。

#### WithNone

`WithNone`约束允许你排除具有一组组件中任意一个或多个组件的实体，ComponentSystem为所有不具有Rotation组件的实体执行以下lambda函数：
```CSharp
Entities.WithNone<Rotation>().ForEach( (Entity e) =>
{
    // do stuff
});
```

另外，你可以使用`WithAnyReadOnly`来筛选具有一组组件任意一个的实体，以及`WithAllReadOnly`来筛选具有全部指定的一组组件的实体；并且只是将它们作为只读组件进行查询。这确保了它们不会被标记为已写入，以及它们的块ID被更改。

### 选项
你还可以使用多种With来为查询

|Option|Description|
|-|-|
|Default|未指定选项|
|IncludePrefab|该查询不会隐式地排除具有特殊Prefab组件的实体|
|IncludeDisabled|该查询不会隐式地排除具有特殊Disable组件的实体|
|FilterWriteGroup|该查询应该过滤基于设置了[WriteGroupAttribute](https://docs.unity3d.com/Packages/com.unity.entities@0.3/manual/ecs_write_groups.html)的组件查询的实体|


ComponentSystem对所有不具有Rotation组件的实体（包括那些具有特殊的Disable组件的实体）执行以下lambda函数：
```CSharp
Entities.WithNone<Rotation>().With(EntityQueryOptions.IncludeDisabled).ForEach( (Entity e) =>
{
    // do stuff
});
```

<a name="5"></a>
## 使用 IJobChunk

你可以在JobComponentSystem中实现IJobChunk以逐块遍历数据。JobComponentSystem为每个包含你需要处理的实体的块执行一次Execute()函数。然后，你可以逐个实体地处理每个块的数据。

与IJobForEach相比，使用IJobChunk进行遍历需要更多的代码设置，但是也更加明确，并且代表对数据的最直接访问，因为访问的顺序和在内存中的布局一样。

按块遍历的另一个好处是，你可以检测每个块中是否存在可选组件（使用`Archetype.Has<T>()`），并相应的处理块中所有的实体。


实现IJobChunk job 包括以下步骤：
1. 通过创建EntityQuery标识要处理的实体
2. 定义Job结构，包括ArchetypeChunkComponentType对象的字段，以标识job直接访问的组件类型，并指定job是读取还是写入这些组件。
3. 在系统`OnUpdate()`函数中实例化 job结构并调度job。
4. 在`Execute()`函数中，获取给job读取或写入组件的NativeArray实例，最后遍历当前块以执行所需工作。

[ECS Samples 仓库](https://github.com/Unity-Technologies/EntityComponentSystemSamples)包含一个简单的 HelloCube 例子演示了如何使用IJobChunk。

### 通过 EntityQuery 查询数据
EntityQuery定义原型必须包含的组件类型，系统才能处理其关联的块和实体。该原型也可以包含其他组件，但是必须至少具有EntityQuery定义的组件。你也可以排除包含特定类型组件的原型。

对于简单查询，可以使用 `JobComponentSystem.GetEntityQuery()`传入组件类型：
```CSharp
public class RotationSpeedSystem : JobComponentSystem
{
    private EntityQuery m_Query;

    protected override void OnCreate()
    {
        m_Query = GetEntityQuery(ComponentType.ReadOnly<Rotation>(),
                                 ComponentType.ReadOnly<RotationSpeed>());
        //...
    }
}
```

对于更加复杂的情况，可以使用`EntityQueryDesc`。`EntityQueryDesc`提供了一种灵活的查询机制来指定组件类型：
- All : 原型必须包含数组中所有类型的组件
- Any : 原型必须至少包含数组中任意一种组件
- None : 原型不能包含数组中任意一种组件

例如，以下查询 包含 RotationQuaternion和RotationSpeed组件，但不包含Frozen组件的任何原型：
```CSharp
protected override void OnCreate()
{
    var queryDescription = new EntityQueryDesc()
    {
        None = new ComponentType[]
        {
            typeof(Static)
        },
        All = new ComponentType[]
        {
            ComponentType.ReadWrite<Rotation>(),
            ComponentType.ReadOnly<RotationSpeed>()
        }
    };
    m_Query = GetEntityQuery(queryDescription);
}
```

该查询使用`ComponentType.ReadOnly<T>`而不是简单的`typeof`表达式来指定系统不写入的RotationSpeed。

你还可以通过传递EntityQueryDesc对象的数组而不是单个实例来组合多个查询。每个查询都使用逻辑或运算进行组合。下面示例选择包含RotationQuaternion组件或RotationSpeed组件（或两者）的原型：
```CSharp
protected override void OnCreate()
{
    var queryDescription0 = new EntityQueryDesc
    {
        All = new ComponentType[] {typeof(Rotation)}
    };

    var queryDescription1 = new EntityQueryDesc
    {
        All = new ComponentType[] {typeof(RotationSpeed)}
    };

    m_Query = GetEntityQuery(new EntityQueryDesc[] {queryDescription0, queryDescription1});
}
```

>注意：
请不要在`EntityQueryDesc`中包括完整的可选组件。要处理可选组件，请在`IJobChunk.Execute()`中使用`chunk.Has<T>()`方法确定当前ArchetypeChunk是否具有可选组件。之所以不需要包括完整的可选组件，是由于同一个块中的所有实体具有完全相同的组件类型，因此，你只需要检查每个块是否存在一个可选组件，而不是每个实体一次。

为了提高效率并避免创建不必要的垃圾收集的引用类型，你应该创建EntityQueries并将结果存储在实例变量中。（上面例子中的 m_Query变量就是用于此目的）

### 定义IJobChunk结构
`IJobChunk`结构定义了job运行时所需的数据字段以及job的`Execute()`方法。

为了访问系统传递给`Execute()`方法的块中的组件，你需要为job读写的每个组件类型创建一个`ArchetypeChunkComponentType<T> `对象，这些对象允许你获取NativeArray的实例，来提供对对组件的访问，包括`Execute()`方法读写的，由job的EntityQuery中引用的所有组件。你还可以未包含在EntityQuery中的可选组件类型提供`ArchetypeChunkComponentType`变量。（你必须检测确保当前块具有该可选组件，然后再尝试访问它）

例如，HelloCube IJobChunk 示例声明了一个job结构，该结构为 RotationQuaternion 和 RotationSpeed 两个组件定义了 `ArchetypeChunkComponentType<T>`变量：

```CSharp
[BurstCompile]
struct RotationSpeedJob : IJobChunk
{
    public float DeltaTime;
    public ArchetypeChunkComponentType<Rotation> RotationType;
    [ReadOnly] public ArchetypeChunkComponentType<RotationSpeed> RotationSpeedType;

    public void Execute(ArchetypeChunk chunk, int chunkIndex, int firstEntityIndex)
    {
        // ...
    }
}
```
系统在`OnUpdate()`函数中为这些变量分配值。ECS框架运行job时，将在`Execute()`内部使用这些变量。

job还使用了Unity 的 delta time 来为3D对象设置旋转动画。这个例子中，也把这些值通过结构体的字段传递给`Execute()`方法。

### 编写Execute 方法

IJobChunk Execute() 方法的签名为：
```
public void Execute(ArchetypeChunk chunk, int chunkIndex, int firstEntityIndex)
```
块参数是内存块的句柄，该内存块包含job的当前迭代要处理的实体和组件。由于块只能存在一个原型，因此，块中的所有实体都具有相同的组件集。

使用chunk参数获取组件的NativeArray 实例：
```CSharp
var chunkRotations = chunk.GetNativeArray(RotationType);
var chunkRotationSpeeds = chunk.GetNativeArray(RotationSpeedType);
```

对其这些数组，以使实体在所有数组中都具有相同的索引。然后，你可以使用常规的for循环遍历组件数组。使用`chunk.Count`来获取当前块中存储的实体数：
```CSharp
var chunkRotations = chunk.GetNativeArray(RotationType);
var chunkRotationSpeeds = chunk.GetNativeArray(RotationSpeedType);
for (var i = 0; i < chunk.Count; i++)
{
    var rotation = chunkRotations[i];
    var rotationSpeed = chunkRotationSpeeds[i];

    // Rotate something about its up vector at the speed given by RotationSpeed.
    chunkRotations[i] = new Rotation
    {
        Value = math.mul(math.normalize(rotation.Value),
            quaternion.AxisAngle(math.up(), rotationSpeed.RadiansPerSecond * DeltaTime))
    };
}
```
如果你的EntityQueryDesc中的Any过滤器，或没有在查询中出现的完整可选组件（即只是选取了某个或部分，并没有写完整，前面也提过，不需要写完整，可以通过接下了的步骤进行判断和获取），则可以在使用该组件之前先使用`ArchetypeChunk.Has<T>()`函数来测试当前块是否包含这些组件：

```CSharp
if (chunk.Has<OptionalComp>(OptionalCompType))
{
  //...
}
```

>注意：
如果使用部分实体命令缓存，则将chunkIndex参数作为jobIndex参数传递给命令缓存函数。

### 跳过具有不变实体的块

如果仅在组件值发生更改时才需要更新实体，则可以将该组件添加到为job选择块和实体的EntityQuery的更改筛选器中。例如，如果你的系统读取两个组件，并且只有前面两个组件中的一个发生改变时，才需要更新第三个组件。你可以使用下面的EntityQuery:
```CSharp
private EntityQuery m_Query;

protected override void OnCreate()
{
    m_Query = GetEntityQuery(
        ComponentType.ReadWrite<Output>(),
        ComponentType.ReadOnly<InputA>(),
        ComponentType.ReadOnly<InputB>());
    m_Query.SetChangedVersionFilter(
        new ComponentType[]
        {
            ComponentType.ReadWrite<InputA>(),
            ComponentType.ReadWrite<InputB>()
        });
}
```
EntityQuery 变更过滤器最多支持两个组件。如果想要检查更多或不使用EntityQuery，你可以自己手动检测。要进行此检测，请使用`ArchetypeChunk.DidChange（）`函数将组件的块的变更版本与系统中的`LastSystemVersion`进行比较。如果返回false，则可以完全跳过当前块，因为自上次系统运行以来，该类型组件的值均未发生改变。

来自系统的`LastSystemVersion`必须通过结构体中的字段传递到job中：
```CSharp
[BurstCompile]
struct UpdateJob : IJobChunk
{
    public ArchetypeChunkComponentType<InputA> InputAType;
    public ArchetypeChunkComponentType<InputB> InputBType;
    [ReadOnly] public ArchetypeChunkComponentType<Output> OutputType;
    public uint LastSystemVersion;

    public void Execute(ArchetypeChunk chunk, int chunkIndex, int firstEntityIndex)
    {
        var inputAChanged = chunk.DidChange(InputAType, LastSystemVersion);
        var inputBChanged = chunk.DidChange(InputBType, LastSystemVersion);

        // If neither component changed, skip the current chunk
        if (!(inputAChanged || inputBChanged))
            return;

        var inputAs = chunk.GetNativeArray(InputAType);
        var inputBs = chunk.GetNativeArray(InputBType);
        var outputs = chunk.GetNativeArray(OutputType);

        for (var i = 0; i < outputs.Length; i++)
        {
            outputs[i] = new Output{ Value = inputAs[i].Value + inputBs[i].Value };
        }
    }
}
```

与所有Job结构字段一样，你必须在安排job之前为它们赋值：
```CSharp
protected override JobHandle OnUpdate(JobHandle inputDependencies)
{
    var job = new UpdateJob();

    job.LastSystemVersion = this.LastSystemVersion;

    job.InputAType = GetArchetypeChunkComponentType<InputA>(true);
    job.InputBType = GetArchetypeChunkComponentType<InputB>(true);
    job.OutputType = GetArchetypeChunkComponentType<Output>(false);

    return job.Schedule(m_Query, inputDependencies);
}
```

>注意：
为了提高效率，版本的变更应用于整个块，而不是单个实体。如果另一个job已访问了一个块，则该块的变更版本将会增加，并且`DidChange()`函数会返回ture。尽管声明了具有写权限的job并没有改变组件的值，变更版本也会增加。所以，对于不改变数组值的访问应该尽可能的使用只读权限。

### 实例化并安排job

要运行IJobChunk job，必须创建Job结构的实例，设置结构的字段，然后安排job调度。

在JobComponentSystem的OnUpdate()函数中自行此操作时，系统会每帧安排一次job的调度。

```CSharp
protected override JobHandle OnUpdate(JobHandle inputDependencies)
{
    var job = new RotationSpeedJob()
    {
        RotationType = GetArchetypeChunkComponentType<Rotation>(false),
        RotationSpeedType = GetArchetypeChunkComponentType<RotationSpeed>(true),
        DeltaTime = Time.DeltaTime
    };
    return job.Schedule(m_Query, inputDependencies);
}
```

调用`GetArchetypeChunkComponentType<T>`函数设置组件类型变量时，请确保将Job只读但不写入的组件的IsReadOnly 设置为true。正确的设置这些参数可能会对ECS调度jobs的效率产生重大的影响。这些访问模式设置，必须在结构体定义和EntityQuery中都与它们的等效项匹配。

不要在系统类变量中缓存`GetArchetypeChunkComponentType<T>`的返回值。每当系统运行时，都必须调用该函数，更新该值并传递给job。

<a name="6"></a>
## 手动遍历
你还可以在NativeArray 中显示请求所有块，并使用Job(例如 IJobParallelFor)处理它们。如果你需要以某种方式管理块，而该方式不适用于适用的遍历EntityQuery中所有的块的简单模式，那么建议适用此方法：

```CSharp
public class RotationSpeedSystem : JobComponentSystem
{
   [BurstCompile]
   struct RotationSpeedJob : IJobParallelFor
   {
       [DeallocateOnJobCompletion] public NativeArray<ArchetypeChunk> Chunks;
       public ArchetypeChunkComponentType<RotationQuaternion> RotationType;
       [ReadOnly] public ArchetypeChunkComponentType<RotationSpeed> RotationSpeedType;
       public float DeltaTime;

       public void Execute(int chunkIndex)
       {
           var chunk = Chunks[chunkIndex];
           var chunkRotation = chunk.GetNativeArray(RotationType);
           var chunkSpeed = chunk.GetNativeArray(RotationSpeedType);
           var instanceCount = chunk.Count;

           for (int i = 0; i < instanceCount; i++)
           {
               var rotation = chunkRotation[i];
               var speed = chunkSpeed[i];
               rotation.Value = math.mul(math.normalize(rotation.Value), quaternion.AxisAngle(math.up(), speed.RadiansPerSecond * DeltaTime));
               chunkRotation[i] = rotation;
           }
       }
   }

   EntityQuery m_Query;   

   protected override void OnCreate()
   {
       var queryDesc = new EntityQueryDesc
       {
           All = new ComponentType[]{ typeof(RotationQuaternion), ComponentType.ReadOnly<RotationSpeed>() }
       };

       m_Query = GetEntityQuery(queryDesc);
   }

   protected override JobHandle OnUpdate(JobHandle inputDeps)
   {
       var rotationType = GetArchetypeChunkComponentType<RotationQuaternion>();
       var rotationSpeedType = GetArchetypeChunkComponentType<RotationSpeed>(true);
       var chunks = m_Query.CreateArchetypeChunkArray(Allocator.TempJob);   //直接请求查询选择的所有块

       var rotationsSpeedJob = new RotationSpeedJob
       {
           Chunks = chunks,
           RotationType = rotationType,
           RotationSpeedType = rotationSpeedType,
           DeltaTime = Time.deltaTime
       };
       return rotationsSpeedJob.Schedule(chunks.Length,32,inputDeps);
   }
}

```

### 在ComponentSystem中手动遍历

尽管不是通常推荐的方法，不过，你确实可以使用EntityManager类手动遍历实体和块。这些遍历方法仅应在测试，或调试代码（或进行试验测试），又或者你拥有完全受控的实体集的孤立世界中使用。

例如：以下代码循环访问当前Active World 中的所有实体：

```CSharp
var entityManager = World.Active.EntityManager;
var allEntities = entityManager.GetAllEntities();
foreach (var entity in allEntities)
{
   //...
}
allEntities.Dispose();
```

而这一段代码则是遍历了Active World 中的所有块

```CSharp
var entityManager = World.Active.EntityManager;
var allChunks = entityManager.GetAllChunks();
foreach (var chunk in allChunks)
{
   //...
}
allChunks.Dispose();
```
