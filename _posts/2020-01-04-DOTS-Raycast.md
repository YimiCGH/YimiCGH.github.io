---
layout: post
title: '关于在DOTS中使用射线检测'
categories:
      - 笔记
tags:
  - DOTS
  - Physics
  - Unity
last_modified_at: 2020-01-04T02:00:00-02:05
---
{% include toc %}
---
因为旧系统的射线无法检测到ECS中的碰撞体，因此，我们需要找到一种新的方法，来在DOTS中进行射线检测。

经过一番搜索查找，做到了一种比较简单的方法。实现如下：

```CS

BuildPhysicsWorld m_buildPhysicsWorldSystem;

//在系统创建的时候
protected override void OnCreate()
{
    m_buildPhysicsWorldSystem = World.GetOrCreateSystem<BuildPhysicsWorld>();

    //Unity 的新输入系统
    m_inputManager = new SimpleRTSInput();
    m_inputManager.Enable();

    Application.quitting += OnDestroy;

    m_inputManager.Player.Fire.started += OnClick;
}

//...

void OnClick(InputAction.CallbackContext callbackContext) {
        //接收到鼠标点击事件时
        Debug.Log(callbackContext.ReadValue<float>());

        //射线检测
        //借助旧相同中的坐标装换
        var mousPos = Mouse.current.position.ReadValue();
        UnityEngine.Ray ray = m_camera.ScreenPointToRay(mousPos);

        RaycastInput raycastInput = new RaycastInput {
            Start = ray.origin,
            End = ray.origin + ray.direction * 100,
            Filter = CollisionFilter.Default // TODO改为只检测地面
        };

        CollisionWorld collisionWorld = m_buildPhysicsWorldSystem.PhysicsWorld.CollisionWorld;
        if (collisionWorld.CastRay(raycastInput, out Unity.Physics.RaycastHit hit)) {
            Debug.Log(hit.Position);
            var hitEntity = collisionWorld.Bodies[hit.RigidBodyIndex].Entity;//奇怪，我没有给它们加上Rigibody，哪来的Rigibody组件
            //Debug.Log("hit entity "+hitEntity.Index);

            SetGoal((int)math.floor( hit.Position.x),(int)math.floor(hit.Position.z));
        }
    }
```



---
解决过程
- 先去官方论坛上进行 [射线检测问题搜索](https://forum.unity.com/search/127806420/?q=Raycast&t=post&o=date&c[node]=422)
- 找到了论坛上一位仁兄的疑惑，恰好解决了我的问题[Raycast and collision with entities without rigidbodies](https://forum.unity.com/threads/raycast-and-collision-with-entities-without-rigidbodies.791282/#post-5265996)

- 其他以后可能会遇上的问题。[Converting a prefab with collider then instantiating it at runtime with Unity.Physics
](https://forum.unity.com/threads/converting-a-prefab-with-collider-then-instantiating-it-at-runtime-with-unity-physics.787988/)
