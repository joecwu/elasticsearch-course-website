# Uncle Joe's Ops Tips

## Cache

```
# 查看 Filter Cache 的命中率
GET /_nodes/stats/indices/query_cache?human



```


## Thread

```
# 確認 Thread Pool 狀態
GET /_cat/thread_pool?v&s=t,n&h=type,name,node_name,active,queue,rejected,completed

# 確認是否有 Long Running Tasks 成為 Hot Thread
GET /_nodes/hot_threads
```

## Tasks

```
# 查看 Long Running Tasks
GET /_tasks?filter_path=nodes.*.tasks
```