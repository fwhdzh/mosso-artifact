# xraft

A raft implementation of XnnYygn's.

I want to make something with netty framework, and I found raft. Raft is interesting. As the first distributed consensus algorithm I learnt, I read the paper and implemented almost all of the feature of raft including

* Leader election and log replication
* Membership change(one server change)
* Log compaction

All these feature are implemented in xraft-core. And the client interaction in raft, I thought, should be the feature of service based on xraft-core. Until now, I made a simple key value store based on xraft-core, called xraft-kvstore. It supports GET and SET command.

## Demostration

To test xraft with xraft-kvstore, you can download xraft and run xraft-kvstore, xraft-kvstore-cli.

### Prerequistes

Java 1.8+ is required to run xraft. You can run `java -version` to check the version of java on your computer.

### Download

You can get complied xraft in releases.

### Run Server

`xraft-kvstore` under the `bin` directory is the command to run xraft kvstore server.

To demostrate a xraft cluster with 3 nodes(memory log mode), 

* node A, host localhost, port raft node 2333, port kvstore 3333
* node B, host localhost, port raft node 2334, port kvstore 3334
* node C, host localhost, port raft node 2335, port kvstore 3335

start servers with commands below

Terminal A

```
$ bin/xraft-kvstore -gc A,localhost,2333 B,localhost,2334 C,localhost,2335 -m group-member -i A -p2 3333
```

Terminal B

```
$ bin/xraft-kvstore -gc A,localhost,2333 B,localhost,2334 C,localhost,2335 -m group-member -i B -p2 3334
```

Terminal C

```
$ bin/xraft-kvstore -gc A,localhost,2333 B,localhost,2334 C,localhost,2335 -m group-member -i C -p2 3335
```

Since the minimum election timeout is 3 seconds, if you cannot execute all 3 commands within 3 seconds, you will get some error like `failed to connect ....`. But after you started all nodes, the error will disapper.

After start, you will see something like `become leader`, `current leader is xxx` and it shows the cluster is started and leader election is ok.

### Run Client

Run `xraft-kvstore-cli` with the cluster configuration. The client will not connect to any node in cluster so it is ok to run client before cluster starts.

```
$ bin/xraft-kvstore-cli -gc A,localhost,3333 B,localhost,3334 C,localhost,3335
```

It will run an interative console, press TAB two times and you will get the available commands. For this demostration, firstly run 

```
> kvstore-get x
```

and you should get the result `null`. Then run

```
> kvstore-set x 1
```

nothing will be printed, now you can run get again.

```
> kvstore-get x
```

`1` should be printed.

## New Service

How to create new service based on xraft-core?

* [Node & NodeBuilder](https://github.com/xnnyygn/xraft/wiki/Node-&-NodeBuilder)
* [StateMachine](https://github.com/xnnyygn/xraft/wiki/StateMachine)

For more detailed implementation of new service, see the source code of xraft-kvstore.

## Build

xraft use [Maven](https://maven.apache.org/) as build system.

```
$ mvn clean compile install
```

To package xraft-kvstore

```
$ cd xraft-kvstore
$ mvn package assembly:single
```

## About PreVote

If you are looking for Raft optimization `PreVote`, please check `develop` branch.

## Consistency in xraft-kvstore

To make the implmenetation simple, the `xraft-kvstore` just reads the value in the concurrent hash map, which actually could be a stale value. There is an optimiation in `develop` branch called `readindex` to offer consistent read. If you need consistent read or want to know how to implement it, please refer to `develop` branch.

## License

This project is licensed under the MIT License.

## 关于《分布式一致性算法开发实战》和相关讨论

2020年5月，我出版了一本书，名字叫做[《分布式一致性算法开发实战》](https://book.douban.com/subject/35051108/)。书里面大部分代码都是参考我的这个项目，或者说我是先完成了这个项目然后再写了书。如果你对项目本身的架构，设计选择或者算法本身等有兴趣的话，欢迎阅读《分布式一致性算法开发实战》，我在书里做了很多详细的讲解。

另外，如果你对书籍或者代码设计有疑问的话，或者想要交流的话，欢迎在[豆瓣页面的讨论区](https://book.douban.com/subject/35051108/)内发表话题，我会定期检查并回复。
