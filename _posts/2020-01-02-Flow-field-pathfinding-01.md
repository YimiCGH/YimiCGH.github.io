---
layout: post
title: '流场寻路算法-FLowField（01）'
categories:
      - 笔记
tags:
  - Unity
last_modified_at: 2019-12-31T23:00:00-23:00
---
{% include toc %}
---
## 概述
关于流场寻路算法有许多种称呼，如，力场，向量场，势场。不过都是叫法不一样，其理念都差不多，就是利用网格（当然不局限于网格，也可以抽象为节点和图）来存储目标点到其他所有可达点的向量，该向量可以表示该点到目标点产生的推力。然后，网格上的单位可以根据所在网格产生的推力进行移动。

该算法可以解决RTS或者其他需要对大量单位进行寻路的情况，对比对所有单位进行一次寻路计算，流场算法只需要进行一次计算，就可以将该结果应用于全部单位。

>实际情况中，不能因为一次寻路就影响到所有单位，因为这些单位中，有玩家选中的，玩家未选中的，其他正在移动的，敌人的单位等等。因此，根据实际情况和使用场景，需要对该算法做些改进。

下面简单记录一下流场算法的一些核心内容。

## 主要算法
流场寻路分为三个组成部分：
- 热度图：通过计算网格上所有格子与目标点的路径距离来生成
- 向量场：通过前面的热度图生成向量场，该向量场指定了到达目的的方向
- 自主操控行为：搜索共同目标的所有单位，都通过该向量场来导航到目标点

### 热度图的生成
热度图保存了每个格子到目标点的路径距离。（路径距离和欧几里得距离不同，欧几里得距离是两点间的直接）
可以通过 [迪捷斯科拉泛洪算法](https://howtorts.github.io/2013/12/31/generating-a-path-dijkstra.html) ，来生成网格上的数字。

算法主要思路是，从目标点开始，以前后左右四个方向进行递归遍历，和寻路时所使用的有些不同，这里并没有终点，而是洪泛式遍历完整个地图，来填充每个格子到起点的距离。（这里其实可以进行一些优化，只进行局部遍历，不需要把这个地图都遍历完毕，为了简单起见，这里就先不讲这个）

```js
HeatMap.prototype.upadte = function(){
  this.openList.length = 0;
  this.closeList.length = 0;
  var index = G_TargetPoint.x + G_TargetPoint.y * cols;
  this.dis[G_TargetPoint.x][G_TargetPoint.y] = 0;
  this.openList.push(index);

  while (this.openList.length > 0) {
    var p = this.openList[0];
    this.closeList.push(p);
    this.openList = this.openList.slice(1);//从openList删除该节点
    var y = int(p / cols);
    var x = p - y * cols;
    this.GetNeighbor(x,y,this.dis[x][y]);
  }
}

HeatMap.prototype.GetNeighbor = function(_x,_y,_value){
  var neighbors = [];
  neighbors[0]  = createVector(_x    ,_y - 1);//up
  neighbors[1]  = createVector(_x + 1,_y);//right
  neighbors[2]  = createVector(_x    ,_y + 1);//down
  neighbors[3]  = createVector(_x - 1,_y);//left

  for (var i = 0; i < neighbors.length; i++) {
    var neighbor = neighbors[i];
    if(
      neighbor.x >= 0 && neighbor.x < cols &&
      neighbor.y >= 0 && neighbor.y < rows)
    {
      if(G_WalkableMap.walkable[neighbor.x][neighbor.y] == 1){//格子可通行
        var index = neighbor.x + neighbor.y * cols;
        if(!ArrayHas(this.openList,index) && !ArrayHas(this.closeList,index)){
          this.openList.push(index);
          this.dis[neighbor.x][neighbor.y] = _value + 1;
        }
      }
    }
  }
}
```
![image-center]({{ '/images/blog023/000.png' | absolute_url }}){: .align-center}

### 向量图生成
得到热度图后
通过遍历每个方块（不包括不可通行方块），查找它所有的相邻方块（包括斜角），选择抵达目标点路径距离最短的那个，然后把当前网格的向量设置为指向该方块的矢量。

最终生成如图所示的向量场
<img src="https://howtorts.github.io/images/flowfield.png" class="align-center" alt="">

不过，我们可以进一步对此向量场进行优化，如，不允许其斜着穿过障碍。具体方法是在遍历当前点的8方向邻居时，过滤掉不可通行的，以及斜角方向时，该斜角上一个和下一个邻居。就可以得到如图所示效果

![image-center]({{ '/images/blog023/001.png' | absolute_url }}){: .align-center}

仔细观察可以发现其实是有点缺陷的，当和目标点之间没有任何障碍时，正常情况下它应该直接指向目标点，代理应该直线移动过去比较自然。但是因为我们当前的向量场只支持正交直线以及45度角的直线，类似这种情况的斜线并不支持。《最高指挥官2》中使用视线检测附近是否有更好的路径来实现。

### 转向力

关于转向力，是由 Craig Reynolds 提出的一种自主操控行为，通过对各种行为定义对环境的感知来产生转向力，继而驱动单位进行运动。文章后面可以找到相关的参考资料。

我们使用流场来驱动单位的运动，因此，我们需要获取单位所在格子上的向量

当我们得到单位所在格子上的向量后，接下来，就可以使用自主操控行为中转向力的概念来移动物体。
```js
Vehicle.prototype.follow = function(_flowfield){
  var desired = _flowfield.lookup(this.location).copy();

  desired.normalize();
  desired.mult(this.maxSpeed);

  var steer = desired.sub(this.velocity);
  steer.limit(this.maxForce);

  return steer;
}
```

#### 平滑转向力
为了可以沿着向量场进行移动，我们将实现一种操控行为，该行为将为代理的指定其所在格子的方向。为了平滑该矢量，我们使用双线性插值法（[Bilinear Interpolation](https://wiki.tw.wjbk.site/wiki/%E5%8F%8C%E7%BA%BF%E6%80%A7%E6%8F%92%E5%80%BC)），这样，我们就可以收到最近的四个格子的影响，且最接近的格子的影响最大。

关于双线性插值，简单的描述一下。

就是通过四个已知点。Q<sub>11</sub>,Q<sub>12</sub>,Q<sub>21</sub>,Q<sub>22</sub>

<img src="https://gss2.bdstatic.com/9fo3dSag_xI4khGkpoWK1HF6hhy/baike/c0%3Dbaike80%2C5%2C5%2C80%2C26/sign=b1170590fc039245b5b8e95de6fdcfa7/54fbb2fb43166d223d93e6c9462309f79152d283.jpg" class="align-center" alt="">

先求X方向的线性插值，即
- Q<sub>11</sub> 和 Q<sub>21</sub> 之间的R<sub>1</sub>
- Q<sub>12</sub> 和 Q<sub>22</sub> 之间的R<sub>2</sub>

然后求Y方向的线性插值，即通过前面求出的R<sub>1</sub> 和R<sub>2</sub> 在y方向上插值计算出P点。

通过该方法可以求出这四个点内任意位置的插值，通常用来对图片像素采样。

利用这个原理，我们对代理当前所在格子周围的格子进行双线性插值。

```js
function steeringBehaviourFlowField(agent) {
  //Work out the force to apply to us based on the flow field grid squares we are on.
  //we apply bilinear interpolation on the 4 grid squares nearest to us to work out our force.
  // http://en.wikipedia.org/wiki/Bilinear_interpolation#Nonlinear
  var floor = agent.position.floor(); //把当前位置约束为网格坐标  
  /*
  | 00 | 10 |
  | 01 | 11 |
  */
  var hasRigth = (x + 1 < cols);
  var hasBottom = (y + 1 < rows);
  //如果其他格子为空（越界）或者格子不可通行，则取当前格子
  var f00 = this.field[x][y];//当前所在格子
  var f10 = hasRigth ? this.field[x + 1][y] : f00;
  var f01 = hasBottom ? this.field[x][y + 1] : f00;
  var f11 = (hasRigth && hasBottom) ? this.field[x+1][y + 1] : f00;
	//X方向上的采样
  var xWeight = agent.position.x - floor.x;

  var top = V.lerp(f00,f10,xWeight);
  var bottom = V.lerp(f01,f11,xWeight);

	//Y方向上的采样
  var yWeight = agent.position.y - floor.y;

	//最终移动方向
  var direction = Vector.lerp(top , bottom , yWeight).normalize();

  //当我们在没有矢量的网格中心，就会发生下面情况
  if (isNaN(direction.length())) {
  	return Vector2.zero;
  }

  //Multiply our direction by speed for our desired speed
  var desiredVelocity = direction * agent.maxSpeed;

  //The velocity change we want
  var velocityChange = desiredVelocity - agent.velocity;
  //Convert to a force
  return velocityChange * (agent.maxForce / agent.maxSpeed);
}
```

### 绕开墙
关于障碍的规避比较容易理解。如图，向单位前方投射一个射线（也可以像图中投射一个矩形），当检测到前方有障碍时，会产生一个转向力使得单位偏移原来的运动轨迹。简单方法是获取该物体到射线的法向量，然后取反。
<img src="https://www.red3d.com/cwr/steer/gdc99/figure7.gif" class="align-center" alt="">

可以查看转向理论的作者的一些文章，里面还提到了许多有趣的行为，例如，沿着路径移动，沿着墙移动。基于这些思想，我们也可以实现自己的转向行为。如，绕开墙！

下面，就介绍如何怎么实现。

墙的法向量。
我们假设墙的有四个顶点：v0,v1,v2,v3。单位的视线 `LineOfSight = unit.forward - unit.location`;


从[线段相交：维基百科](https://en.wikipedia.org/wiki/Line%E2%80%93line_intersection)这里我们可以拿到线段相交的判断公式，我们就不进行推到，直接使用，主要有两个参数来判定，t 是交点在第一个线段上位置，u 是交点在第二个线段上的位置。它们的取值范围都为[0,1]。

然后将墙的每条边依次和单位的视线进行相交检测

```js
function CrossPoint(_p1,_p2,_p3,_p4){
  const x1 = _p1.x;
  const y1 = _p1.y;
  const x2 = _p2.x;
  const y2 = _p2.y;

  const x3 =_p3.x;
  const y3 = _p3.y;
  const x4 = _p4.x;
  const y4 = _p4.y;

  const den = (x1-x2) * (y3-y4) - (y1-y2) * (x3-x4);
  //分母为0，表示两线段不相交，即平行
  if(den == 0){
    return null;
  }

  const t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den;// 如果 0 <= t <= 1.0，表示交点落在第一个线段内
  const u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / den;//如果 0 <= u <= 1.0 ，表示交点落在第二个线段内

  if(t > 0 && t < 1 && u > 0 && u < 1){
    const pt = createVector();
    pt.x = x1 + t * (x2 - x1);
    pt.y = y1 + t * (y2 - y1);
    return pt;
  }else{
    return null;
  }
}
```

得到交点后，我们就可以获取墙的法线方向，假设相交的边为 `L = V1 - V0`,则法线方向为 `N = new Vector(-L.y,L.x)`,即简单的将边的方向的XY调换后，然后随便取反一个，具体是哪一个可以自己进行测试，和边的方向有关。

接下来就是根据 t 或 u 来获取交点在线段的位置，假设我们把墙的边作为第一个线段输入，那么我们就使用t来判断，如果t > 0.5 ,则与单位前进方向的端点为 V1 ，否则为 V0。
```js
var f_dir =p5.Vector.sub(_location,_forward).normalize();
var lineDir = p5.Vector.sub(v1,v0).normalize();
var dot = p5.Vector.dot(f_dir,lineDir);

if(dot > 0){
  conner = v0;
}else{
  conner = v1;
}
```

如图

![image-center]({{ '/images/blog023/002.png' | absolute_url }}){: .align-center}

最终我们得到了两个力，一个是墙的反向推力，另一个是沿着墙的边缘的拉力.把这些力作用到单位上，可以得到不错的效果

## 抵达行为

普通的抵达行为
```js
Vehicle.prototype.arrive = function(_targetPos){
  var desired = _targetPos.sub(this.location);

  var distance = desired.mag();

  if(distance < 100){
    var m = map(distance,0,100,0,this.maxSpeed);
    desired.setMag(m);
  }else{
    desired.setMag(this.maxSpeed);
  }

  var steer = desired.sub(this.velocity);
  steer.limit(this.maxForce);

  return steer;
}
```

流场中的抵达行为
```js
Vehicle.prototype.FlowFieldArrive = function(_flowfield){

  //var desired = _flowfield.lookup(this.location).copy();//直接获取所在格子上的向量
  var desired = _flowfield.lookup_smooth(this.location).copy();//采用双向性采样获取向量

  desired.normalize();
  var targetPos = G_TargetPoint.copy().add(0.5,0.5).mult(resolution);
  var distance = targetPos.sub(this.location).mag();

  if(distance < 100){
    var m = map(distance,0,100,0,this.maxSpeed);
    desired.setMag(m);
  }else{
    desired.setMag(this.maxSpeed);
  }

  var steer = desired.sub(this.velocity);
  steer.limit(this.maxForce);
  return steer;
}
```



----
【参考】
- [Website/Blog about the things you need to know to make a modern RTS game](https://howtorts.github.io/)
- [Basic Flow Fields](https://howtorts.github.io/2014/01/04/basic-flow-fields.html)
- [Understanding Goal-Based Vector Field Pathfinding](https://gamedevelopment.tutsplus.com/tutorials/understanding-goal-based-vector-field-pathfinding--gamedev-9007)
- [游戏中的人工智能之流场寻路](https://blog.csdn.net/zjq2008wd/article/details/51192765)
- [Steering Behaviors For Autonomous Characters - by Craig W. Reynolds](https://www.red3d.com/cwr/steer/gdc99/)
- [Boids - by Craig Reynolds](https://www.red3d.com/cwr/boids/)
--
[有趣的示例](https://howtorts.github.io/examples/4-basic-flow-fields/index.html)
