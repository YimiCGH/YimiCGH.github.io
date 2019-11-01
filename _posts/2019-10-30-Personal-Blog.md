---
layout: post
title: '个人博客搭建'
excerpt: "摘要：记录一下搭建博客的过程，顺便写一下值得纪念的第一篇博客"
image:
  path: /images/study.jpg
  thumbnail: /images/study.jpg
tags:
  - 生活随笔

last_modified_at: 2019-10-31T22:26:59-05:00
---

## 个人博客搭建

> 因为一直羡慕别人有一个自己的博客文章，心动不如行动，自己DIY一个，过程并不顺利，不过还是勉勉强强的弄出来了，下面记录一下搭建的过程以及遇到的坑。

### 介绍
本文使用的是[jekyll](https://jekyllrb.com/)，Jekyll是一个静态站点的生成器，有非常丰富的插件功能和模板，通过它，只需要简单几步就可以马上生成一个静态网站,下图就是官方给出的样式：

![image-center]({{ '/images/blog001/002.png' | absolute_url }}){: .align-center}

jekyll确实非常便利，把所有的脏活都干了，我们只需要简单调用几句命令就可以了。

>在实际的使用过程中，我们更多的是修改别人分享的主题模板，因为这些主题或多或少的使用了某些插件，所以经常只需要调用 `bundle install `,然后再运行 `bundle exec jekyll s`就可以启动本地网站，然后通过 `127.0.0.1:4000`就可以访问到这个网站,测试没问题后就可以上传到github 使用Github Page功能来 配置个人站点，这样别人就可以通过 `XXX.github.io`来访问你刚刚在本地看到的那些页面
>

**注意：**
(需要先创建一个名为`XXX.github.io`的仓库，`XXX`值的是你的github用户名）。如果自己有域名的话，也可以在该仓库的Setting->GitHub Pages->Custom domain那里配置，然后在域名提供商的域名配置那里设置映射为`XXX.github.io`就OK了

### 配置环境

首先是需要在本地安装jekyll环境，我们通过先安装ruby环境（jekyll是使用ruby编写的）。因为我的本本是windows系统,所以选择 [Rubyinstaller](https://rubyinstaller.org/downloads/) 来安装

![image-center]({{ '/images/blog001/001.png' | absolute_url }}){: .align-center}

**这里选择Ruby + Devkit ，之前自己选了纯ruby环境，然后自己去下载其它资源，结果是因为墙的缘故各种安装失败，整个人都不好了**
#### 具体步骤

![left-aligned-image]({{ '/images/blog001/003.png' | absolute_url }}){: .align-left}
执行 `ruby -v` 查看ruby是否安装成功，成功的话就会显示下面的版本提示

![left-aligned-image]({{ '/images/blog001/004.png' | absolute_url }}){: .align-left}
执行 `gem -v` 查看gem是否安装成功，成功的话就会显示下面的版本提示。gem 是用来安装各种工具包的

然后我们就可以运行 `gem install jekyll`来安装Jekyll了，等待一段时间后会出现安装成功提示
![image-center]({{ '/images/blog001/005.png' | absolute_url }}){: .align-center}


然后直接输入命令`jekyll` ，就可以得到提示，说明安装成功，红色框中的命令是我们以后可能用到的命令
![image-center]({{ '/images/blog001/006.png' | absolute_url }}){: .align-center}

最后安装一个bundler工具，可以用来帮我们安装Jekyll的各种插件工具
![image-center]({{ '/images/blog001/007.png' | absolute_url }}){: .align-center}


#### 总结
上面那么多，其实无非就三步
- 安装ruby - 通过官网下载Rubyinstaller进行安装
- 安装jekyll - `gem install jekyll`
- 安装bundler - `gem install jekyll bundler`

### Jekyll 使用
前面安装配置完毕后，就可以开始创建自己的网站了!
输入命令 `jekyll new testblog`,会开始在我的用户目录下创建一个testblog文件夹，并在里面创建各种目录和文件。

也可以自行指定创建到哪个文件夹中
- 创建一个新的文件夹
- 使用 `cd` 命令跳转到该文件夹中
- 然后`jekyll new .` ，不要忘记`.`，表示在当前目录下创建

![image-center]({{ '/images/blog001/008.png' | absolute_url }}){: .align-center}

创建完毕后，我们跳转进入这个目录下，然后执行`bundle install`，来安装依赖，因为jekyll帮我们生成的博客系统可能有某些依赖，为了保证这些依赖都安装了，我们先执行一下`bundle install`以防万一。以后我们下载别人的模板下来后也是用这个命令来安装缺失的依赖。
（记得是进入这个目录后再执行，自己之前因为漏了这一步，折腾了好久）
执行完毕后，等待一段时间，就可以看到如下提示，表示安装成功
![image-center]({{ '/images/blog001/009.png' | absolute_url }}){: .align-center}
最后一步，执行`bundle exec jekyll s`命令启动网站
![image-center]({{ '/images/blog001/010.png' | absolute_url }}){: .align-center}
打开浏览器，输入`127.0.0.1:4000` 就可以范围我们创建好的网站了
![image-center]({{ '/images/blog001/011.png' | absolute_url }}){: .align-center}

### 主题下载 与 上传至Github
下面给出一些分享的jekyll主题网站
[jekyllthemes](http://jekyllthemes.org/)
[Free Jekyll Themes](https://jekyllthemes.io/free)
可以再上面下载自己需要的，作者一般都会对自己分享的主题做使用说明，有问题也可以请教作者。
下载下来后修改成自己的，然后上传到github，配置一下就可以访问了

<figure class="align-center">
  <a href="#"><img src="{{ '/images/blog001/012.png' | absolute_url }}" alt=""></a>
  <figcaption>1.创建仓库 </figcaption>
</figure>

<figure class="align-center">
  <a href="#"><img src="{{ '/images/blog001/013.png' | absolute_url }}" alt=""></a>
  <figcaption>2.设置域名 </figcaption>
</figure>
设置完毕后就可以通过XXX.github.io访问刚刚的网站了。

这里特别指出一下两个文件夹的作用
- `_drafts` 是用来存储未发表的文章，也就是草稿箱
- `_posts` 是用来存放已发布的文章

![image-center]({{ '/images/blog001/014.png' | absolute_url }}){: .align-center}

### Gitalk 安装
最后提一下[Gitalk](https://github.com/gitalk/gitalk)的安装，这里也被坑了好久
官方也有比较详细的说明文件
使用也比较简单
<figure class="align-center">
  <a href="#"><img src="{{ '/images/blog001/017.png' | absolute_url }}" alt=""></a>
  <figcaption>1.创建 <a href="https://github.com/settings/applications/new">GitHub Application</a>  </figcaption>
</figure>
<figure class="align-center">
  <a href="#"><img src="{{ '/images/blog001/018.png' | absolute_url }}" alt=""></a>
  <figcaption>2.获取id  </figcaption>
</figure>
<figure class="align-center">
  <a href="#"><img src="{{ '/images/blog001/016.png' | absolute_url }}" alt=""></a>
  <figcaption>3.设置_config.yml</figcaption>
</figure>

4 再`_includes`文件夹下创建`gitalk.html`文件

``` javascript
<div id="gitalk-container"></div>

<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/gitalk@1/dist/gitalk.css">
<script src="https://cdn.jsdelivr.net/npm/gitalk@1/dist/gitalk.min.js"></script>

<script>
  const gitalk = new Gitalk({
    clientID: '{{site.comments.client_id}}',
    clientSecret: '{{site.comments.client_secret}}',
    repo: '{{site.comments.repo}}',
    owner: '{{site.comments.owner}}',
    admin: ['{{site.comments.admin}}'],
    label: ['Gitalk'],
    id: decodeURI(location.pathname),      // Ensure uniqueness and length less than 50
    distractionFreeMode: false  // Facebook-like distraction free mode
  })
  gitalk.render('gitalk-container')
</script>
```

<figure class="align-center">
  <a href="#"><img src="{{ '/images/blog001/016.png' | absolute_url }}" alt=""></a>
  <figcaption>5.编辑post.html</figcaption>
</figure>

最后重新启动网站，刷新一下，就可以看到评论框了

---

## 自言自语的Yimi
>从今天开始，可以肆无忌惮的乱搞啦，哈哈！
把自己的学习过程记录下来，希望自己可以变成自己憧憬的样子！尽管路途坎坷，迷茫过，失落过，挣扎过，自暴自弃过，可终究不想就这样一蹶不振。一直认为自己是个失败的人，到现在还是一事无成。不过，我还没有放弃希望，只有自己放弃了，才是真正的失败。人生有梦不觉寒，尽管四处黑暗，我还有星光相随，偶尔会失去星光，但是，守得云开见月明，遇到挫折不要气馁，勇敢的面对它，跨过它。
一直呆在舒适区是没办法成长，要主动跳出舒适区，去迎接困难和挑战，才能让自己变得更加强大。

### 目标：称为一个独立游戏制作人
>现阶段的实力还远远不够，需要掌握的技能还有很多，不过这些都不是一朝一夕就能掌握的，急不来，需要慢慢积累，沉淀。技能杂而不精也不好，所以，需要有一个压箱底的大招才行，有前辈让我往图形学这一块去挖深，尝试了一段时间后，感觉太吃力，而且有点迷茫，不知道怎么去深入，感觉不合适自己，所以打算另寻出路，最后发现人工智能这一块是自己比较感兴趣的，兴趣是最大的老师，能够创建出栩栩如生的角色未尝不是一件快乐的事。

>其它技能嘛，像画画，音乐，也是需要花很大的精力去坚持练习的，一旦松懈，又功亏一篑
以前就立过不少Flag，没一件事干好。
如果能把每一件理所当然的事情干好，结果自然是理所当然。但是一件理所当然的的事都干不好，那只能说明自己有问题了。

加油吧！为了幸福的未来，奔跑吧，骚年！
