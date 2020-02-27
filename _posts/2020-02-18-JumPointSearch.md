---
layout: post
title: 'JPS 跳点寻路算法'
categories:
      - 翻译
tags:
  - AI
  - Pathfinding
  - RTS
last_modified_at: 2020-01-10T02:00:00-02:05
---
{% include toc %}
---


## 算法介绍

JPS算法是基于`A*`算法的扩展实现，也就是说，我们还是会使用到`A*`的启发方式来挑选下一个扩展节点，只不过，JPS会对候选的扩展节点进行裁剪。例如下面两张图。x 表示当前检测的节点，箭头表示它的前继方向（即它是从哪一个节点来的）。灰色的地方表示将会裁剪掉的邻居节点，白色的地方才是需要的扩展节点。

<img src="https://harablog.files.wordpress.com/2011/09/jps_natural.png" class="align-center" alt="">

也就是说，上图左边的进行裁剪后，实际上只剩下5号节点，右图裁剪后实际只剩下2，3，5号节点。我们简单起见，现在只是介绍了向右和向右上扩展时的情况（另外6 个方向其实道理一样）。

另外，需要注意强制邻居节点。
<img src="https://harablog.files.wordpress.com/2011/09/jps_forced.png" class="align-center" alt="">
当x沿着箭头方向进行扩展时，当x和障碍物相邻时，图中被圈起来的节点无法被裁剪，该节点也被称为强制邻居节点。

为什么叫做强制邻居节点？因为他会强制结束本次跳跃的进行。例如，节点x一直在朝着右边进行扩展，突然遇到一个障碍出现在它的上面（出现在下面的情况时，强制邻居为8），此时我们会结束跳跃，把当前x节点和强制邻居节点压入OpenSet。这样一来，我们就直接略过中间大部分节点的扩展搜索，并直接从新压入的跳点开始搜索。

其实，以上就算JPS的核心思想，下面我们就基于`A*`算法对其进行改造，将我们的GeiNeighbors方法进行修改，不在时获取8个方向的邻居，而是经过裁剪后的邻居。


## A*搜索

```js
function Search(){
  if(done){
    return;
  }

  //执行搜索中
  var lowest_id = 0;
  var lowest_f = openSet[lowest_id].f;
  for (var i = 1; i < openSet.length; i++) {
    if(openSet[i].f < lowest_f){
      lowest_id = i;
      lowest_f = openSet[i].f;
    }
  }
  var current = openSet[lowest_id];
  RemoveFormArray(openSet,current);
  closedSet.push(current);
  if(current == end){
    done = true;
    console.log("Done!");
    return;
  }

  if(current.cameFrom != null){
    //取得移动方向
    var dir_x = constrain(current.x - current.cameFrom.x ,-1,1);
    var dir_y = constrain(current.y - current.cameFrom.y ,-1,1);
    GetNeighbors_WithCut(current,dir_x,dir_y);
  }else{
    GetNeighbors(current);
  }

  for (var i =  0; i < neighbors.length ; i++) {
    var neighbor = neighbors[i];

    var jumpNode = jump(neighbor,current,grid);
    if(jumpNode != null && !closedSet.includes(jumpNode)){

      var g_score = current.g + floor( dist(jumpNode.x,jumpNode.y,current.x,current.y) * 10) / 10;

      if(openSet.includes(jumpNode)){
        if(g_score < jumpNode.g){
          jumpNode.g = g_score;//是一个更加近的节点
          jumpNode.cameFrom = current;
        }
      }else{
        jumpNode.g = g_score;
        jumpNode.cameFrom = current;
        openSet.push(jumpNode);
      }

      jumpNode.h = Heuristic(jumpNode,end) ;
      jumpNode.f = jumpNode.g + jumpNode.h;
    }
  }

}

function Heuristic(_spot,_end){
  return abs(_spot.x - _end.x) + abs(_spot.y - _end.y) ;
}
```

获取邻居
```js

function GetNeighbors(_spot){
  neighbors.length = 0;
  for (var i = 0; i < 8; i++) {
    var dir = grid.drections[i];
    var neighbor = grid.getNeighbor(_spot,dir.x,dir.y);
    if(neighbor != null && neighbor.cost != 0){
      if((i % 2) != 0){//对角
        var last_dir =  grid.drections[(i - 1) % 8];
        var next_dir =  grid.drections[(i + 1) % 8];

        var last = grid.getNeighbor(_spot,last_dir.x,last_dir.y);
        var next = grid.getNeighbor(_spot,next_dir.x,next_dir.y);
        if(last != null && last.cost == 0 && next != null && next.cost == 0){
          console.log("对角");
        }else{
          neighbors.push(neighbor);
        }

      }else{
        neighbors.push(neighbor);
      }
    }
  }
}

function GetNeighbors_WithCut(_spot,_dirx,_diry){
  neighbors.length = 0;
  if(_dirx != 0 && _diry != 0){
    //斜角
    neighbors = DiagonalTest(grid,_spot,_dirx,_diry);
  }else{
    //非斜角
    if(_dirx != 0){
      neighbors = HorizontalTest(grid,_spot,_dirx);
    }else{
      neighbors = VerticalTest(grid,_spot,_diry);
    }
  }
}
```

## 裁剪

```js
function AddForceNeighbor(_cell,_grid,list,_dirx,_diry){
  var forceNeighbor = _grid.getNeighbor(_cell,_dirx,_diry);
  if(forceNeighbor != null && forceNeighbor.cost != 0){
      list.push(forceNeighbor);
  }
}


function HorizontalTest(_grid,_currentCell,_dir){
  var res = [];
  var nextCell = _grid.getNeighbor(_currentCell,_dir,0);
  if(nextCell == null){
    return res;
  }else{
    if(nextCell.cost != 0){
      res.push(nextCell);
    }
  }
  var upCell = _grid.getNeighbor(_currentCell,0,-1);
  var downCell = _grid.getNeighbor(_currentCell,0,1);

  //发现强制邻居节点
  if(upCell != null){
    if(_dir == 1){
      AddForceNeighbor_D(_currentCell,_grid,res,0,2,1);
    }else{
      AddForceNeighbor_D(_currentCell,_grid,res,0,6,7);
    }
  }
  if(downCell != null ){
    if(_dir == 1){
      AddForceNeighbor_D(_currentCell,_grid,res,4,2,3);
    }else{
      AddForceNeighbor_D(_currentCell,_grid,res,4,6,5);
    }
  }
  return res;
}
function VerticalTest(_grid,_currentCell,_dir){
  var res = [];
  var nextCell = _grid.getNeighbor(_currentCell,0,_dir);
  if(nextCell == null){
    return res;
  }else{
    if(nextCell.cost != 0){
      res.push(nextCell);
    }
  }
  var leftCell = _grid.getNeighbor(_currentCell,-1,0);
  var rightCell = _grid.getNeighbor(_currentCell,1,0);

  //发现强制邻居节点
  if(leftCell != null){
    if(_dir == 1){
      AddForceNeighbor_D(_currentCell,_grid,res,6,4,5);
    }else{
      AddForceNeighbor_D(_currentCell,_grid,res,6,0,7);
    }
  }
  if(rightCell != null){
    if(_dir == 1){
      AddForceNeighbor_D(_currentCell,_grid,res,2,4,3);
    }else{
      AddForceNeighbor_D(_currentCell,_grid,res,2,0,1);
    }
  }
  return res;
}
function DiagonalTest(_grid,_currentCell,_dirx,_diry){
  var res = [];
  var nextCell = _grid.getNeighbor(_currentCell,_dirx,_diry);


  var nextVCell = _grid.getNeighbor(_currentCell,0,_diry);//垂直方向
  var nextHCell = _grid.getNeighbor(_currentCell,_dirx,0);//水平方向

  if(nextVCell != null && nextVCell.cost != 0){
    res.push(nextVCell);
  }
  if(nextHCell != null && nextHCell.cost != 0){
    res.push(nextHCell);
  }
  if(nextVCell != null && nextVCell.cost == 0 &&
    nextHCell != null &&  nextHCell.cost == 0){
    //不允许穿过两个不可通行的节点之间
    return res;
  }else{
    if(nextCell != null && nextCell.cost != 0){
      res.push(nextCell);
    }
  }

  //发现强制邻居节点
  if(_dirx == 1 && _diry == -1){
    //右上
    AddForceNeighbor_D(_currentCell,_grid,res,6,0,7);
    AddForceNeighbor_D(_currentCell,_grid,res,4,2,3);
  }else if(_dirx == 1 && _diry == 1){
    //右下
    AddForceNeighbor_D(_currentCell,_grid,res,0,2,1);
    AddForceNeighbor_D(_currentCell,_grid,res,6,4,5);
  }else if(_dirx == -1 && _diry == 1){
    //左下
    AddForceNeighbor_D(_currentCell,_grid,res,0,6,7);
    AddForceNeighbor_D(_currentCell,_grid,res,2,4,3);
  }else{
    AddForceNeighbor_D(_currentCell,_grid,res,2,0,1);
    AddForceNeighbor_D(_currentCell,_grid,res,4,6,5);
  }

  return res;
}
//考虑斜角，不需从两个墙之间穿过
function AddForceNeighbor_D(_cell,_grid,list,_close,_open,_add){
  var closeCell = _grid.getNeighbor_byDirID(_cell,_close);
  var openCell = _grid.getNeighbor_byDirID(_cell,_open);
  if(openCell == null)
    return;
  if(closeCell.cost == 0 &&
    openCell.cost != 0){
    var dir = _grid.drections[_add];
    AddForceNeighbor(_cell,_grid,list,dir.x,dir.y);
  }
}
```

### 跳跃

```js
function jump(_neighbor,_current,_grid){
  if(_neighbor == null || _neighbor.cost == 0){
    return null;
  }

  if(_neighbor == end){
    return _neighbor;
  }

  var dx = _neighbor.x - _current.x;
  var dy = _neighbor.y - _current.y;

  var forceNeighbor1 = null;
  var obstacle1 = null;
  var forceNeighbor2 = null;
  var obstacle2 = null;

  if((dx & dy) != 0){
    //斜角
    forceNeighbor1 = _grid.getNeighbor(_neighbor,-dx,dy);
    obstacle1 = _grid.getNeighbor(_neighbor,-dx,0);
    forceNeighbor2 = _grid.getNeighbor(_neighbor,dx,-dy);
    obstacle2 = _grid.getNeighbor(_neighbor,0,-dy);

    if(HasForceNeighbor(forceNeighbor1,obstacle1,forceNeighbor2,obstacle2)){
      return _neighbor;
    }
    if(jump(_grid.getNeighbor(_neighbor,dx,0) ,_neighbor,_grid) != null ||
       jump(_grid.getNeighbor(_neighbor,0,dy) ,_neighbor,_grid) != null){
      return _neighbor;
    }
  }else{
    if(dx != 0){
      forceNeighbor1 = _grid.getNeighbor(_neighbor,dx,1);
      obstacle1 = _grid.getNeighbor(_neighbor,0,1);
      forceNeighbor2 = _grid.getNeighbor(_neighbor,dx,-1);
      obstacle2 = _grid.getNeighbor(_neighbor,0,-1);

    }else if(dy != 0){
      forceNeighbor1 = _grid.getNeighbor(_neighbor,-1,dy);
      obstacle1 = _grid.getNeighbor(_neighbor,-1,0);
      forceNeighbor2 = _grid.getNeighbor(_neighbor,1,dy);
      obstacle2 = _grid.getNeighbor(_neighbor,1,0);
    }
    if(HasForceNeighbor(forceNeighbor1,obstacle1,forceNeighbor2,obstacle2)){
      return _neighbor;
    }
  }

  var H_cell = _grid.getNeighbor(_neighbor,dx,0);
  var V_cell = _grid.getNeighbor(_neighbor,0,dy);

  if((H_cell != null && H_cell.cost != 0) || (V_cell != null && V_cell.cost != 0)){
    var D_Cell =  _grid.getNeighbor(_neighbor,dx,dy);
    return jump(D_Cell,_neighbor,_grid);
  }else{
    return null;
  }
}

function HasForceNeighbor(forceNeighbor1 ,obstacle1,forceNeighbor2,obstacle2){
  if((obstacle1 != null && obstacle1.cost == 0 &&
     forceNeighbor1 != null && forceNeighbor1.cost != 0) ||
  (obstacle2 != null && obstacle2.cost == 0 &&
     forceNeighbor2 != null && forceNeighbor2.cost != 0)){
    return true;
  }
}
```

## 学习总结


---
参考文献
- [A Visual Explanation of Jump Point Search](https://zerowidth.com/2013/a-visual-explanation-of-jump-point-search.html)
- [A Visual Explanation of Jump Point Search(知乎翻译)](https://zhuanlan.zhihu.com/p/25093275)
- [Jump Point Search (算法原作者的文章)](https://harablog.wordpress.com/2011/09/07/jump-point-search/)
- [Improving Jump Point Search (论文)](chrome-extension://ikhdkkncnoglghljlkmcimlnlhkeamad/pdf-viewer/web/viewer.html?file=https%3A%2F%2Fusers.cecs.anu.edu.au%2F~dharabor%2Fdata%2Fpapers%2Fharabor-grastien-icaps14.pdf)
