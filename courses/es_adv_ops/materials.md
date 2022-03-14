# Elasticsearch 進階運維班

## 1. 深入 Elasticsearch 分散式架構

### 1-1 Elasticsearch Cluster 的形成與維護機制

#### Demo: 使用同一份 ES 執行檔，準備 3 個 nodes 的 cluster

1. 先準備好一份 `elasticsearch.yml` for node: `es01`

```
cluster.name: uncle-joe
node.name: es01
path.data: data01
path.logs: logs01
discovery.seed_hosts:
  - localhost:9301
  - localhost:9302
cluster.initial_master_nodes: 
  - es01
  - es02
  - es03
xpack.security.enabled: false

network.host: [_local_, _site_]
# 如果要方便分辨哪個 node 在哪個 port，可以直接指定
http.port: 9200
transport.port: 9300
```

2. 複製 `config` 目錄至 `config01` ~ `config03` 共 3 份。

3. 修改每一個目錄中的 `elasticsearch.yml` ，將流水號 `01` 改成對應的編號、port 也要改成不重覆的編號，`seed_hosts` 也要設定當下 node 的其他 master-eligible nodes 的 transport port。

for node: `es02`

```
cluster.name: uncle-joe
node.name: es02
path.data: data02
path.logs: logs02
discovery.seed_hosts:
  - localhost:9300
  - localhost:9302
cluster.initial_master_nodes: 
  - es01
  - es02
  - es03
xpack.security.enabled: false

network.host: [_local_, _site_]
# 如果要方便分辨哪個 node 在哪個 port，可以直接指定
http.port: 9201
transport.port: 9301
```

for node: `es03`

```
cluster.name: uncle-joe
node.name: es03
path.data: data03
path.logs: logs03
discovery.seed_hosts:
  - localhost:9300
  - localhost:9301
cluster.initial_master_nodes: 
  - es01
  - es02
  - es03
xpack.security.enabled: false

network.host: [_local_, _site_]
# 如果要方便分辨哪個 node 在哪個 port，可以直接指定
http.port: 9202
transport.port: 9302
```


4. 分別起動 3 個 Nodes (建議在不同視窗中)：

```
ES_PATH_CONF=./config01 ./bin/elasticsearch

ES_PATH_CONF=./config02 ./bin/elasticsearch

ES_PATH_CONF=./config03 ./bin/elasticsearch
```

#### Demo 2: 在 Demo 1 的 cluster 中，加入額外的 2 個 nodes。

1. 需同樣操作 Demo 1 的 step 2 ~ 3，建立資料夾及修改 config。

2. 分別執行 es04 與 es05

```
ES_PATH_CONF=./config04 ./bin/elasticsearch

ES_PATH_CONF=./config05 ./bin/elasticsearch
```

3. 查看 Voting Config 的狀態

```
GET _cluster/state?filter_path=metadata.cluster_coordination
```

```
curl -s 'localhost:9200/_cluster/state?filter_path=metadata.cluster_coordination' | jq
```

### 1-2 各種 Request 的運作原理與例外狀況處理

#### Demo 1: Searching 請求的運作原理 - Pre-Filter

```

DELETE test
PUT test
{
  "settings": {
    "number_of_shards": 5,
    "number_of_replicas": 1
  }
}

PUT test/_doc/1?refresh
{
  "name": "joe",
  "Date": "2022-03-03T00:00:00"
}
PUT test/_doc/2?refresh
{
  "name": "david",
  "Date": "2022-03-04T00:00:00"
}
PUT test/_doc/3?refresh
{
  "name": "amy",
  "Date": "2022-03-05T00:00:00"
}
PUT test/_doc/4?refresh
{
  "name": "alice yoyo",
  "Date": "2022-03-06T00:00:00"
}
PUT test/_doc/5?refresh
{
  "name": "alice aa",
  "Date": "2022-03-07T00:00:00"
}

# 使用 _search 時，配合 date range 和 sort
# shard 數量不到 128 時，query & sort 兩者都滿足時，才會生效
GET test/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "range": {
            "Date": {
              "gte": "2022-03-05T00:00:00"
            }
          }
        }
      ]
    }
  }, 
  "size": 2,
  "sort": [
    "Date"
  ]
}

# 當 shard 數量滿足時(先把大小改成 2)，這時只要有 query 就會生效。
GET test/_search?pre_filter_shard_size=2
{
  "query": {
    "bool": {
      "must": [
        {
          "range": {
            "Date": {
              "gte": "2022-03-05T00:00:00"
            }
          }
        }
      ]
    }
  }, 
  "size": 2,
  "sort": [
    "Date"
  ]
}

```

#### Demo 2: 分散式架構對相關性計分的影響

只有 1 份 primary shard 時：
```
PUT score
{
 "settings": {
   "number_of_shards": 1
 }
}


PUT score/_doc/1?refresh
{
  "doc": "apple"
}

PUT score/_doc/2?refresh
{
  "doc": "apple macbook"
}

PUT score/_doc/3?refresh
{
  "doc": "apple macbook pro"
}

GET score/_search?q=apple
```

有 5 份 primary shard 時：
```
DELETE score

PUT score
{
 "settings": {
   "number_of_shards": 5
 }
}

PUT score/_doc/1?refresh
{
  "doc": "apple"
}

PUT score/_doc/2?refresh
{
  "doc": "apple macbook"
}

PUT score/_doc/3?refresh
{
  "doc": "apple macbook pro"
}

GET score/_search?q=apple
```

查看計分的細節
```
GET score/_search?q=apple&explain=true
```

使用 `dfs_query_then_fetch` search type
```
GET score/_search?q=apple&search_type=dfs_query_then_fetch
```


### 1-3 Shard Allocation

#### Cluster Allocation Explain API

查看某一個 allocation 的狀態
```
PUT shard_alloc
{
  "settings": {
    "number_of_shards": 200,
    "number_of_replicas": 1
  }
}

GET _cluster/allocation/explain
{
  "index": "shard_alloc",
  "primary": false,
  "shard": 0
}

DELETE shard_alloc
```

若是想查看當下全部 unassigned 的 shard，可從 cluster state 查詢
```
GET _cluster/state/routing_nodes?filter_path=routing_nodes.unassigned
```

#### 練習：雙 AZ 以及雙 Rack 的 Cluster

 - `elasticsearch.yml` in Node1 & Node2
```
node.attr.rack: Rack1
node.attr.zone: zoneA
cluster.routing.allocation.awareness.attributes: rack,zone
cluster.routing.allocation.awareness.force.zone.values: zoneA,zoneB
```

 - `elasticsearch.yml` in Node3
```
node.attr.rack: Rack2
node.attr.zone: zoneA
cluster.routing.allocation.awareness.attributes: rack,zone
cluster.routing.allocation.awareness.force.zone.values: zoneA,zoneB
```

 - `elasticsearch.yml` in Node4
```
node.attr.rack: Rack3
node.attr.zone: zoneB
cluster.routing.allocation.awareness.attributes: rack,zone
cluster.routing.allocation.awareness.force.zone.values: zoneA,zoneB
```

 - `elasticsearch.yml` in Node4
```
node.attr.rack: Rack4
node.attr.zone: zoneB
cluster.routing.allocation.awareness.attributes: rack,zone
cluster.routing.allocation.awareness.force.zone.values: zoneA,zoneB
```

- Create `movies` index
```
PUT movies
{
  "settings": {
    "number_of_shards": 5, 
    "number_of_replicas": 2
  }
}
```

- Use the Cluster Allocation Explain API to check the status of shard in specific node.
```
GET _cluster/allocation/explain
{
  "index": "movie",
  "primary": true,
  "current_node": "es04",
  "shard": 2
}
```


### 1-5 Routing 的運用方式


#### Routing Hash Function - `number_of_routing_shards` 的例子

```
# Create a new index with 2 primary shards & 12 routing shards
PUT extensible_shards
{
  "settings": {
    "number_of_shards": 2,
    "number_of_routing_shards": 12
  }
}

# 保留之後能變成 12/2 = 6 的因數的變化 6 = 2 * 3，所以因數是 2 和 3。

# 預先把 Index 改成 read-only
PUT extensible_shards/_settings
{
  "settings": {
    "index.blocks.write": true
  }
}

# 使用 Index Split API 改成 7 (會失敗，不是 2 的倍數)
POST /extensible_shards/_split/splitted_index
{
  "settings": {
    "index.number_of_shards": 7
  }
}

# 使用 Index Split API 改成 8 (會失敗，不是 12 的因數)
POST /extensible_shards/_split/splitted_index
{
  "settings": {
    "index.number_of_shards": 8
  }
}

# 使用 Index Split API 改成 6 (成功)
POST /extensible_shards/_split/splitted_index
{
  "settings": {
    "index.number_of_shards": 6
  }
}

# 查看新 Index 的設定
GET splitted_index

```


#### 誰說 Elasticsearch 在同一個 Index 之中 `_id` 不會重覆

```
PUT duplicated_id
{
  "settings": {
    "number_of_shards": 2
  }
}

PUT duplicated_id/_doc/1?routing=1
{
  "test": 1
}

PUT duplicated_id/_doc/1?routing=4
{
  "test": 1
}

GET duplicated_id/_search
```


#### 練習：自訂 Routing Value

```
PUT user_data
{
  "settings": {
    "index.number_of_shards": 3,
    "index.number_of_routing_shards": 12,
    "index.routing_partition_size": 5
  },
  "mappings": {
    "_routing": {
      "required": true
    }
  }
}

# 查看設定
GET user_data

# 如何看 routing shards?
GET _cluster/state?filter_path=metadata.indices.user_data

```


### 1-6 分散式系統的分頁處理

#### Scroll API

```
GET kibana_sample_data_ecommerce/_search?scroll=5m
{
  "size": 10,
  "_source": [
    "user",
    "order_date",
    "order_id"
  ],
  "sort": [
    {
      "order_date": {
        "order": "desc"
      },
      "order_id": {
        "order": "desc"
      }
    }
  ]
}

POST /_search/scroll
{
    
  "scroll": "5m",
  "scroll_id": "FGluY2x1ZGVfY29udGV4dF91dWlkDXF1ZXJ5QW5kRmV0Y2gBFjdDT3NhcG0zVEJPdW1jTjU5cWhsVlEAAAAAAA4CZBYwdnVFT1Z5T1E1YUptS2gyYnZyNHhn"
}
```


#### Search After

```
GET kibana_sample_data_ecommerce/_search
{
  "size": 10,
  "_source": [
    "user",
    "order_date",
    "order_id"
  ],
  "sort": [
    {
      "order_date": {
        "order": "desc"
      },
      "order_id": {
        "order": "desc"
      }
    }
  ],
  "search_after": [
    1647730080000,
    "592043"
  ]
}
```

#### Point In Time + Search After

建立 PIT
```
POST /kibana_sample_data_ecommerce/_pit?keep_alive=5m

```

使用 PIT 查詢
```
GET _search
{
  "size": 10,
  "sort": [
    {
      "_shard_doc": {
        "order": "desc"
      }
    }
  ],
  "pit": {
    "id": "46ToAwEca2liYW5hX3NhbXBsZV9kYXRhX2Vjb21tZXJjZRZUbTBlVm9fS1I1LVZjV1d6R1hKX1ZnABYwdnVFT1Z5T1E1YUptS2gyYnZyNHhnAAAAAAAAGsycFjdDT3NhcG0zVEJPdW1jTjU5cWhsVlEAARZUbTBlVm9fS1I1LVZjV1d6R1hKX1ZnAAA=",
    "keep_alive": "5m"
  }
}
```

使用 PIT + Search After 查詢
```
GET _search
{
  "size": 10,
  "sort": [
    {
      "_shard_doc": {
        "order": "desc"
      }
    }
  ],
  "search_after": [
    4665
  ],
  "pit": {
    "id": "46ToAwEca2liYW5hX3NhbXBsZV9kYXRhX2Vjb21tZXJjZRZUbTBlVm9fS1I1LVZjV1d6R1hKX1ZnABYwdnVFT1Z5T1E1YUptS2gyYnZyNHhnAAAAAAAAGsycFjdDT3NhcG0zVEJPdW1jTjU5cWhsVlEAARZUbTBlVm9fS1I1LVZjV1d6R1hKX1ZnAAA=",
    "keep_alive": "5m"
  }
}
```

使用 PIT + Slice 查詢
```
GET /_search
{
  "pit": {
    "id": "46ToAwEca2liYW5hX3NhbXBsZV9kYXRhX2Vjb21tZXJjZRZUbTBlVm9fS1I1LVZjV1d6R1hKX1ZnABYwdnVFT1Z5T1E1YUptS2gyYnZyNHhnAAAAAAAAGpq3FjdDT3NhcG0zVEJPdW1jTjU5cWhsVlEAARZUbTBlVm9fS1I1LVZjV1d6R1hKX1ZnAAA=",
    "keep_alive": "1m"
  },
  "slice": {
    "field": "order_date",
    "id": 0,
    "max": 2
  },
  "sort": [
    {
      "order_date": {
        "order": "asc"
      }
    }
  ]
}
```

查看當前 PIT Open Context 的數量
```
GET /_nodes/stats/indices/search
```


### 1.7 Cross Cluster Search

#### CCS 設定

起動 3 個 Cluster

```
cluster.name: uncle-joe-c1
node.name: es01
path.data: data_c01
path.logs: logs_c01
xpack.security.enabled: false
http.port: 9200
transport.port: 9300
```

```
cluster.name: uncle-joe-c2
node.name: es02
path.data: data_c02
path.logs: logs_c02
xpack.security.enabled: false
http.port: 9201
transport.port: 9301
```

```
cluster.name: uncle-joe-c3
node.name: es03
path.data: data_c03
path.logs: logs_c03
xpack.security.enabled: false
http.port: 9202
transport.port: 9302
```

分別到三個 Nodes 設定 Cluster Settings

```
PUT _cluster/settings
{
  "persistent": {
    "cluster": {
      "remote": {
        "uncle-joe-c1": {
          "seeds": [
            "127.0.0.1:9300"
          ]
        },
        "uncle-joe-c2": {
          "seeds": [
            "127.0.0.1:9301"
          ]
        },
        "uncle-joe-c3": {
          "seeds": [
            "127.0.0.1:9302"
          ]
        }
      }
    }
  }
}
```

Curl 指令
```
curl -XPUT "http://localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
{"persistent":{"cluster":{"remote":{"uncle-joe-c1":{"seeds":["127.0.0.1:9300"]},"uncle-joe-c2":{"seeds":["127.0.0.1:9301"]},"uncle-joe-c3":{"seeds":["127.0.0.1:9302"]}}}}}'

curl -XPUT "http://localhost:9201/_cluster/settings" -H 'Content-Type: application/json' -d'
{"persistent":{"cluster":{"remote":{"uncle-joe-c1":{"seeds":["127.0.0.1:9300"]},"uncle-joe-c2":{"seeds":["127.0.0.1:9301"]},"uncle-joe-c3":{"seeds":["127.0.0.1:9302"]}}}}}'

curl -XPUT "http://localhost:9202/_cluster/settings" -H 'Content-Type: application/json' -d'
{"persistent":{"cluster":{"remote":{"uncle-joe-c1":{"seeds":["127.0.0.1:9300"]},"uncle-joe-c2":{"seeds":["127.0.0.1:9301"]},"uncle-joe-c3":{"seeds":["127.0.0.1:9302"]}}}}}'

```

查看 Remote Clusters 狀態
```
GET _remote/info
```

#### CCS 搜尋

分別建立測試資料，在每個 Cluster 的 Node 之中建立資料
```
curl -XPUT "http://localhost:9200/ccr_data/_doc/1" -H 'Content-Type: application/json' -d'{"title":"data 1","count":10}'
curl -XPUT "http://localhost:9201/ccr_data/_doc/2" -H 'Content-Type: application/json' -d'{"title":"data 2","count":20}'
curl -XPUT "http://localhost:9202/ccr_data/_doc/3" -H 'Content-Type: application/json' -d'{"title":"data 3","count":30}'
```

搜尋測試
```
# 單 Cluster
GET ccr_data/_search

# search remote cluster
GET uncle-joe-c3:ccr_data/_search

# search multiple remote clusters
GET uncle-joe-c*:ccr_data/_search
```

斷線測試，關掉 Cluster 3 之後，再次搜尋，可以看到 `_cluster.skipped`
```
# search multiple remote clusters
GET uncle-joe-c*:ccr_data/_search
```

#### Search Shards (取得要搜尋的 Shards)

```
# _search_shards 不支援 Cross Cluster Search，只能對單台搜尋。

GET ccr_data/_search_shards?routing=xxx
```


#### 練習：Cross Cluster Search - Movies

設定三台 Node 的 `elasticsearch.yml`

```
cluster.name: movie-hk
node.name: es1.hk
path.data: data_es1.hk
path.logs: logs_es1.hk
xpack.security.enabled: false
http.port: 9200
transport.port: 9300
```

```
cluster.name: movie-us
node.name: es1.us
path.data: data_es1.us
path.logs: logs_es1.us
xpack.security.enabled: false
http.port: 9201
transport.port: 9301
```

```
cluster.name: movie-tw
node.name: es1.tw
path.data: data_es1.tw
path.logs: logs_es1.tw
xpack.security.enabled: false
http.port: 9202
transport.port: 9302
```

準備 Cluster Settings
```
PUT _cluster/settings
{
  "persistent": {
    "cluster": {
      "remote": {
        "movie-hk": {
          "seeds": [
            "127.0.0.1:9300"
          ],
          "skip_unavailable": true
        },
        "movie-us": {
          "seeds": [
            "127.0.0.1:9301"
          ],
          "skip_unavailable": true
        },
        "movie-tw": {
          "seeds": [
            "127.0.0.1:9302"
          ],
          "skip_unavailable": true
        }
      }
    }
  }
}
```


使用 Curl 設定三個 Clusters
```
curl -XPUT "http://localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
{"persistent":{"cluster":{"remote":{"movie-hk":{"seeds":["127.0.0.1:9300"],"skip_unavailable":true},"movie-us":{"seeds":["127.0.0.1:9301"],"skip_unavailable":true},"movie-tw":{"seeds":["127.0.0.1:9302"],"skip_unavailable":true}}}}}'

curl -XPUT "http://localhost:9201/_cluster/settings" -H 'Content-Type: application/json' -d'
{"persistent":{"cluster":{"remote":{"movie-hk":{"seeds":["127.0.0.1:9300"],"skip_unavailable":true},"movie-us":{"seeds":["127.0.0.1:9301"],"skip_unavailable":true},"movie-tw":{"seeds":["127.0.0.1:9302"],"skip_unavailable":true}}}}}'

curl -XPUT "http://localhost:9202/_cluster/settings" -H 'Content-Type: application/json' -d'
{"persistent":{"cluster":{"remote":{"movie-hk":{"seeds":["127.0.0.1:9300"],"skip_unavailable":true},"movie-us":{"seeds":["127.0.0.1:9301"],"skip_unavailable":true},"movie-tw":{"seeds":["127.0.0.1:9302"],"skip_unavailable":true}}}}}'

```

匯入資料
```
curl -s "https://es.joecwu.com/top_rated_movies.en_US.ndjson" | curl -H 'Content-Type: application/x-ndjson' -XPOST 'localhost:9201/top_rated_movies/_bulk' --data-binary @-

curl -s "https://es.joecwu.com/top_rated_movies.zh_TW.ndjson" | curl -H 'Content-Type: application/x-ndjson' -XPOST 'localhost:9202/top_rated_movies/_bulk' --data-binary @-
```


開始查詢
```
GET movie-tw:top_rated_movies/_search
GET movie-us:top_rated_movies/_search
GET *:top_rated_movies/_search
```


#### Cross Cluster Replication

啟用 Trial
```
curl -X POST "http://localhost:9200/_license/start_trial?acknowledge=true"
curl -X POST "http://localhost:9201/_license/start_trial?acknowledge=true"
curl -X POST "http://localhost:9202/_license/start_trial?acknowledge=true"
```

接著即可使用 Kibana 設定 Cross Cluster Replication
- movie-tw:top_rated_movies -> top_rated_movies_tw
- movie-us:top_rated_movies -> top_rated_movies_us


## 2. 進階資料塑模 (Data Modeling) 與存取方式

### 2.1 關聯式資料的存取

#### 各種關聯式資料

```
# One:One 關聯，轉為 Object
GET kibana_sample_data_flights/_search

# One:Many 關聯 (使用 Array of Object)
GET kibana_sample_data_ecommerce/_search
```

#### Nested Object 的示範 (來自基礎班)

```
PUT nested_fields/_doc/1
{
   "group": "fans",
   "users": [
      {
         "first": "John",
         "last": "Smith"
      },
      {
         "first": "Alice",
         "last": "White"
      }
   ]
}

GET nested_fields/_search 
{
   "query": {
      "bool": {
         "must": [
            {
               "match": {
                  "users.first": "Alice"
               }
            },
            {
               "match": {
                  "users.last": "Smith"
               }
            }
         ]
      }
   }
}

GET nested_fields/_mapping

DELETE nested_fields

PUT nested_fields
{
  "mappings": {
    "properties": {
      "users": {
        "type": "nested"
      }
    }
  }
}

GET nested_fields/_mapping

PUT nested_fields/_doc/1
{
   "group": "fans",
   "users": [
      {
         "first": "John",
         "last": "Smith"
      },
      {
         "first": "Alice",
         "last": "White"
      }
   ]
}

GET nested_fields/_search 
{
   "query": {
      "nested": {
         "path": "users",
         "query": {
            "bool": {
               "must": [
                  {
                     "match": {
                        "users.first": "Alice"
                     }
                  },
                  {
                     "match": {
                        "users.last": "Smith"
                     }
                  }
               ]
            }
         }
      }
   }
}
```

#### Join Type

```
# Mapping
PUT exam
{
  "mappings": {
    "properties": {
      "uid": {
        "type": "keyword"
      },
      "text": {
        "type": "text"
      },
      "relation": { 
        "type": "join",
        "relation": {
          "question": "answer" 
        }
      }
    }
  }
}

# Parent: Question
PUT exam/_doc/1?refresh
{
  "uid": "1",
  "text": "question 1",
  "relation": {
    "name": "question"
  }
}
PUT exam/_doc/2?refresh
{
  "uid": "2",
  "text": "question 2",
  "relation": {
    "name": "question"
  }
}

# Child: Answers
PUT exam/_doc/1-1?refresh&routing=1
{
  "uid": "1-1",
  "text": "Answer 1",
  "relation": {
    "name": "answer",
    "parent": "1"
  }
}
PUT exam/_doc/1-2?refresh&routing=1
{
  "uid": "1-2",
  "text": "Answer 2",
  "relation": {
    "name": "answer",
    "parent": "1"
  }
}
PUT exam/_doc/2-1?refresh&routing=2
{
  "uid": "2-1",
  "text": "Answer 1",
  "relation": {
    "name": "answer",
    "parent": "2"
  }
}

# 查詢所有的 Answers
GET exam/_search
{
  "query": {
    "has_parent": {
      "parent_type": "question",
      "query": {
        "match_all": {}
      }
    }
  }
}

# 查詢包含指定 answer 的 parent
GET exam/_search
{
  "query": {
    "has_child": {
      "type": "answer",
      "query": {
        "match": {
          "text": "2"
        }
      }
    }
  }
}

# 使用 Inner Hits 同時回傳被找到的 childs
GET exam/_search
{
  "query": {
    "has_child": {
      "type": "answer",
      "query": {
        "match": {
          "text": "2"
        }
      },
      "inner_hits": {}
    }
  }
}

# 使用 Aggs 來查看系統替 Join 建立的隱藏欄位
GET exam/_search
{
  "size": 0,
  "aggs": {
    "questions": {
      "terms": {
        "field": "relation#question"
      }
    }
  }
}
```

#### 練習：多層關係的資料建模

```

# Mapping
PUT exam
{
  "mappings": {
    "properties": {
      "uid": {
        "type": "keyword"
      },
      "text": {
        "type": "text"
      },
      "relation": { 
        "type": "join",
        "relation": {
          "question": "answer" 
        }
      }
    }
  }
}

# Parent: Question
PUT exam/_doc/1?refresh
{
  "text": "question 1",
  "relation": {
    "name": "question"
  }
}
PUT exam/_doc/2?refresh
{
  "text": "question 2",
  "relation": {
    "name": "question"
  }
}

# Child: Answers
PUT exam/_doc/3?refresh&routing=1
{
  "text": "Answer 1",
  "relation": {
    "name": "answer",
    "parent": "1"
  }
}
PUT exam/_doc/4?refresh&routing=1
{
  "text": "Answer 2",
  "relation": {
    "name": "answer",
    "parent": "1"
  }
}
PUT exam/_doc/5?refresh&routing=2
{
  "text": "Answer 3",
  "relation": {
    "name": "answer",
    "parent": "2"
  }
}

# Child: comment
PUT exam/_doc/6?refresh&routing=1
{
  "text": "comment 1",
  "relation": {
    "name": "comment",
    "parent": "1"
  }
}
PUT exam/_doc/7?refresh&routing=2
{
  "text": "comment 2",
  "relation": {
    "name": "comment",
    "parent": "2"
  }
}
PUT exam/_doc/8?refresh&routing=2
{
  "text": "comment 3",
  "relation": {
    "name": "comment",
    "parent": "2"
  }
}

# Child: vote !!(這裡的 routing 是要填 question 的 _id)
PUT exam/_doc/9?refresh&routing=2
{
  "text": "vote 1",
  "relation": {
    "name": "vote",
    "parent": "5"
  }
}

# 找出 question 的 text 包含 2 的 answer 與 comment
GET exam/_search
{
  "query": {
    "has_parent": {
      "parent_type": "question",
      "query": {
        "match": {
          "text": "2"
        }
      }
    }
  }
}

# 查詢出 answer 中擁有 vote 的 question，並使用 inner_hits 列出找尋的過程
GET exam/_search
{
  "query": {
    "has_child": {
      "type": "answer",
      "query": {
        "has_child": {
          "type": "vote",
          "query": {
            "match_all": {}
          },
          "inner_hits": {}
        }
      },
      "inner_hits": {}
    }
  }
}
```

### 2.2 事先定義好 Data Model

#### Demo: Dynamic Template

- 將 String 型態的欄位，定義成 `keyword`，而不是預設的 `text` + `keyword`。

```
PUT my-index/
{
  "mappings": {
    "dynamic_templates": [
      {
        "strings": {
          "match_mapping_type": "string",
          "mapping": {
            "type": "keyword"
          }
        }
      }
    ]
  }
}

```

- 將 String 型態的欄位，且欄位名字是 `long_` 開頭，同時不是 `_text` 結尾，就定義成 `long` 型態。

```
PUT my-index/
{
  "mappings": {
    "dynamic_templates": [
      {
        "longs_as_strings": {
          "match_mapping_type": "string",
          "match":   "long_*",
          "unmatch": "*_text",
          "mapping": {
            "type": "long"
          }
        }
      }
    ]
  }
}

```

- 將 `name` 物件裡除了 `middle` 之外的所有欄位，都 copy 到 `full_name` 的欄位，並指定為 `text` 型態。

```
PUT my-index
{
  "mappings": {
    "dynamic_templates": [
      {
        "full_name": {
          "path_match":   "name.*",
          "path_unmatch": "*.middle",
          "mapping": {
            "type":       "text",
            "copy_to":    "full_name"
          }
        }
      }
    ]
  }
}

PUT my-index/_doc/1
{
  "name": {
    "first":  "John",
    "middle": "Winston",
    "last":   "Lennon"
  }
}
```

- 先針對字串欄位給予定義，再來針對所有非字串的欄位，關閉 `doc_values`。

```
PUT my-index
{
  "mappings": {
    "dynamic_templates": [
      {
        "named_analyzers": {
          "match_mapping_type": "string",
          "match": "*",
          "mapping": {
            "type": "text",
            "analyzer": "{name}"
          }
        }
      },
      {
        "no_doc_values": {
          "match_mapping_type":"*",
          "mapping": {
            "type": "{dynamic_type}",
            "doc_values": false
          }
        }
      }
    ]
  }
}

PUT my-index/_doc/1
{
  "english": "Some English text", 
  "count":   5 
}
```

#### 練習：設定適合情境需求的 Dynamic Template

```
PUT _index_template/my_logs
{
  "index_patterns": [
    "logs-*"
  ],
  "template": {
    "mappings": {
      "dynamic": "true",
      "dynamic_templates": [
        {
          "string_message": {
            "match_mapping_type": "string",
            "match": "message",
            "mapping": {
              "type": "text"
            }
          }
        },
        {
          "string_others": {
            "match_mapping_type": "string",
            "mapping": {
              "type": "keyword"
            }
          }
        },
        {
          "unindexed_longs": {
            "match_mapping_type": "long",
            "path_unmatch": "http.*",
            "mapping": {
              "type": "long",
              "index": false
            }
          }
        },
        {
          "unindexed_longs": {
            "match_mapping_type": "double",
            "path_unmatch": "http.*",
            "mapping": {
              "type": "float",
              "index": false
            }
          }
        }
      ]
    }
  },
  "priority": 500,
  "version": 1,
  "_meta": {
    "description": "uncle joe's demo"
  }
}

PUT logs-1/_doc/1
{
  "message": "fulltext search supported",
  "id": "keyword",
  "price": 12.34,
  "volume": 123,
  "http": {
    "status": 200
  }
}

GET logs-1
```

### 2.3 無法事先定義好 Data Model


#### 情境題: 事先所定義的欄位不足，怎麼辦?

- Searching 時指定 runtime field

```
# 定義 `@timestamp` 欄位為 date
PUT rf_test
{
  "mappings": {
    "properties": {
      "@timestamp": {
        "type": "date"
      }
    }
  }
}

# Import Test Data
POST rf_test/_bulk?refresh=true
{"index":{}}
{"@timestamp":1516729294000,"model_number":"QVKC92Q","measures":{"voltage":"5.2","start": "300","end":"8675309"}}
{"index":{}}
{"@timestamp":1516642894000,"model_number":"QVKC92Q","measures":{"voltage":"5.8","start": "300","end":"8675309"}}
{"index":{}}
{"@timestamp":1516556494000,"model_number":"QVKC92Q","measures":{"voltage":"5.1","start": "300","end":"8675309"}}
{"index":{}}
{"@timestamp":1516470094000,"model_number":"QVKC92Q","measures":{"voltage":"5.6","start": "300","end":"8675309"}}
{"index":{}}
{"@timestamp":1516383694000,"model_number":"HG537PU","measures":{"voltage":"4.2","start": "400","end":"8625309"}}
{"index":{}}
{"@timestamp":1516297294000,"model_number":"HG537PU","measures":{"voltage":"4.0","start": "400","end":"8625309"}}

GET rf_test

# 定義 `runtime_mapping` 並編寫從 `doc_value` 將資料拿出並進行處理的規則。
GET rf_test/_search
{
  "runtime_mappings": {
    "day_of_week": {
      "type": "keyword",
      "script": {
        "source": "emit(doc['@timestamp'].value.dayOfWeekEnum.getDisplayName(TextStyle.FULL, Locale.ROOT))"
      }
    }
  },
  "fields": [
    "day_of_week"
  ]
}

# 定義 `runtime_mapping` 並編寫從 `_source` 將資料拿出並進行處理的規則。
GET rf_test/_search
{
  "runtime_mappings": {
    "mode_number": {
      "type": "keyword",
      "script": {
        "source": "emit(params._source.model_number)"
      }
    }
  },
  "fields": [
    "model_number"
  ]
}

```

- 將 runtime fields 的定義搬到 index mapping 中

```
# 使用 update mapping API 將 runtime fields 定義進 index mapping 之中
PUT rf_test/_mapping
{
  "runtime": {
    "day_of_week": {
      "type": "keyword",
      "script": {
        "source": "emit(doc['@timestamp'].value.dayOfWeekEnum.getDisplayName(TextStyle.FULL, Locale.ROOT))"
      }
    }
  },
  "properties": {
    "@timestamp": {
      "type": "date"
    }
  }
}

# 使用 _search 將 fields 查出
GET rf_test/_search?docvalue_fields=day_of_week

```

#### 當我們想將 Runtime Field 正式定義

```
# 定義一個新的 Index (用來儲存之後進來的資料)
PUT rf_test_2
{
  "mappings": {
    "properties": {
      "@timestamp": {
        "type": "date"
      },
      "day_of_week": {
        "type": "keyword",
        "on_script_error": "fail",
        "script": {
          "source": "emit(doc['@timestamp'].value.dayOfWeekEnum.getDisplayName(TextStyle.FULL, Locale.ROOT))"
        }
      }
    }
  }
}

# Import Test Data
POST rf_test_2/_bulk?refresh=true
{"index":{}}
{"@timestamp":1516729294000,"model_number":"QVKC92Q","measures":{"voltage":"5.2","start": "300","end":"8675309"}}
{"index":{}}
{"@timestamp":1516642894000,"model_number":"QVKC92Q","measures":{"voltage":"5.8","start": "300","end":"8675309"}}
{"index":{}}

# 查詢 w/ fields
GET rf_test_2/_search?docvalue_fields=day_of_week
```

#### Async Search

```
# 我們嘗試使用 _async_search 但是發現執行太快，不會觸發 async_search
POST rf_test/_async_search
{
  "size": 0, 
  "aggs": {
    "test": {
      "date_histogram": {
        "field": "@timestamp",
        "fixed_interval": "2m"
      }
    }
  }
}

# 強制執行 `wait_for_completion_timeout=0` 讓查詢立刻先返回，即出現 async_search id
POST rf_test/_async_search?wait_for_completion_timeout=0
{
  "size": 0, 
  "aggs": {
    "test": {
      "date_histogram": {
        "field": "@timestamp",
        "fixed_interval": "2m"
      }
    }
  }
}

# 使用 id 去查詢執行狀態
GET _async_search/status/<responsed_async_search_id>

# 再使用 id 去取得結果
GET _async_search/<responsed_async_search_id>

# 也可以使用 `keep_on_completion`
POST rf_test/_async_search?keep_on_completion
{
  "size": 0, 
  "aggs": {
    "test": {
      "date_histogram": {
        "field": "@timestamp",
        "fixed_interval": "2m"
      }
    }
  }
}

# 用完記得要刪除，不然會留 5 天
DELETE _async_search/<responsed_async_search_id>


# 可使用 .async_search 觀察 docs 數量的變化
GET .async-search/_search?size=0
```

### 2.4 Data Model 的事後修改

#### Update by Query

```
# 加上 `joe` 的 tag
POST kibana_sample_data_logs/_update_by_query
{
  "script": {
    "source": "ctx._source.tags.add(params.tag)",
    "lang": "painless",
    "params": {
      "tag": "joe"
    }
  }, 
  "query": {
    "match_all": {}
  }
}

# 移掉 `joe 的 tag，使用 `wait_for_completion=false` 成為 background task
POST kibana_sample_data_logs/_update_by_query?wait_for_completion=false
{
  "script": {
    "source": "if (ctx._source.tags.contains(params.tag)) { ctx._source.tags.remove(ctx._source.tags.indexOf(params.tag)) }",
    "lang": "painless",
    "params": {
      "tag": "joe"
    }
  }, 
  "query": {
    "match_all": {}
  }
}

# 取得 task 結果
GET /_tasks/<task_id>

```


#### 情境題：將先前例子的 `day_of_week` 擷取出來

```
# 首先要將 Runtime field 移掉，並加上靜態的 day_of_week 定義
PUT rf_test/_mapping
{
  "runtime": {
    "day_of_week": null
  },
  "properties": {
    "day_of_week": {
      "type": "keyword"
    }
  }
}

# 接著使用 _update_by_query 將 day_of_week 擷取出來，並存放於 day_of_week 欄位中。
POST rf_test/_update_by_query
{
  "script": {
    "source": """
long milliSinceEpoch = ctx._source.get('@timestamp');
Instant instant = Instant.ofEpochMilli(milliSinceEpoch);
ZonedDateTime zdt = ZonedDateTime.ofInstant(instant, ZoneId.of('Z'));
    ctx._source.day_of_week=zdt.dayOfWeekEnum.getDisplayName(TextStyle.FULL, Locale.ROOT)
    """,
    "lang": "painless"
  }, 
  "query": {
    "match_all": {}
  }
}
```

#### Reindex API

```
# 建立新的 Index Mapping
PUT rf_test_new
{
  "mappings": {
    "properties": {
      "day_of_week": {
        "type": "keyword"
      }
    }
  }
}

# 執行 Reindex
POST _reindex
{
  "source": {
    "index": "rf_test"
  },
  "dest": {
    "index": "rf_test_new"
  },
  "script": {
    "source": """
long milliSinceEpoch = ctx._source.get('@timestamp');
Instant instant = Instant.ofEpochMilli(milliSinceEpoch);
ZonedDateTime zdt = ZonedDateTime.ofInstant(instant, ZoneId.of('Z'));
    ctx._source.day_of_week=zdt.dayOfWeekEnum.getDisplayName(TextStyle.FULL, Locale.ROOT)
    """,
    "lang": "painless"
  }
}

# 查看結果
GET rf_test_new/_search
```


## 2. Data Ingestion

### 2.1 Ingest Pipeline

#### Dissect (demo: create on Kibana as well)

```

POST _ingest/pipeline/_simulate
{
  "pipeline": {
  "description" : "parse multiple patterns",
  "processors": [
    {
      "dissect": {
        "field": "message",
        "pattern" : "%{clientip} %{ident} %{auth} [%{@timestamp}] \"%{verb} %{request} HTTP/%{httpversion}\" %{status} %{size}"
       }
    }
  ]
},
"docs":[
    {
      "_source": {
        "message": "8.8.8.8 - - [30/Apr/1998:22:00:52 +0000] \"GET /english/venues/cities/images/montpellier/18.gif HTTP/1.0\" 200 3171"
      }
    }
  ]
}


```

### Grok

```

# `field`：從哪個欄位中讀取資料。
# `patterns`：Grok patterns 的描述字串，可以使用已經定義好的 patterns，也可以自己定義。(上例是將比對到的結果，存放到 `pet` 欄位中)
# `pattern_definitions`：可以自行指定相同字串比對的規則，值的宣告中，也可以使用 `|` 來定義多個值。
# `trace_match`：是否要回傳 `_grok_match_index` 這個 grok 執行結果的資訊。


POST _ingest/pipeline/_simulate
{
  "pipeline": {
  "description" : "parse multiple patterns",
  "processors": [
    {
      "grok": {
        "field": "message",
        "patterns": ["%{FAVORITE_DOG:pet}", "%{FAVORITE_CAT:pet}"],
        "pattern_definitions" : {
          "FAVORITE_DOG" : "beagle",
          "FAVORITE_CAT" : "burmese"
        },
        "trace_match": true
      }
    }
  ]
},
"docs":[
  {
    "_source": {
      "message": "I love burmese cats!"
    }
  }
  ]
}

```

### GeoIP

```
PUT _ingest/pipeline/geoip
{
  "description" : "Add geoip info",
  "processors" : [
    {
      "geoip" : {
        "field" : "clientip"
      }
    }
  ]
}
PUT geoiop_test/_doc/1?pipeline=geoip
{
  "clientip": "8.8.8.8"
}
GET geoiop_test/_doc/1

```

- 在 kibana 再次操作上面的例子
- testing data for kibana UI

```
[
  {
    "_source": {
      "clientip": "8.8.8.8"
    }
  }
]
```

### Others: `uri_parts`

```
# create uri_parts on Kibana

PUT _ingest/pipeline/uri_parts
{
  "processors": [
    {
      "uri_parts": {
        "field": "request"
      }
    }
  ]
}

```

### Pipeline (Kibana UI)

```
# add dissect, geoip, uri_parts

# test data
[
  {
    "_source": {
      "message": "8.8.8.8 - - [30/Apr/1998:22:00:52 +0000] \"GET /english/venues/cities/images/montpellier/18.gif HTTP/1.0\" 200 3171"
    }
  },
  {
    "_source": {
      "message": "61.195.147.131 - - [09/Jan/2015:19:12:06 +0000] \"GET /inventoryService/inventory/purchaseItem?userId=20253471&itemId=23434300 HTTP/1.1\" 500 17"
    }
  }
]

# add one more processor - K/V
# field: url.query
# field split: &
# value split: =
# Ignore missing

```

### Enrich Processor

```
# prepare source index
PUT /users/_doc/1?refresh=wait_for
{
  "email": "mardy.brown@asciidocsmith.com",
  "first_name": "Mardy",
  "last_name": "Brown",
  "city": "New Orleans",
  "county": "Orleans",
  "state": "LA",
  "zip": 70116,
  "web": "mardy.asciidocsmith.com"
}

# create policy
PUT /_enrich/policy/users-policy
{
  "match": {
    "indices": "users",
    "match_field": "email",
    "enrich_fields": [
      "first_name",
      "last_name",
      "city",
      "zip",
      "state"
    ]
  }
}

# execute policy
POST /_enrich/policy/users-policy/_execute

# check index & alias created by enrich policy
GET .enrich-users-policy

# create ingest pipeline (可以從 kibana 建立)
PUT /_ingest/pipeline/user_lookup
{
  "processors" : [
    {
      "enrich" : {
        "description": "Add 'user' data based on 'email'",
        "policy_name": "users-policy",
        "field" : "email",
        "target_field": "user",
        "max_matches": "1"
      }
    }
  ]
}

# testing data for kibana
[
  {
    "_source": {
      "email": "mardy.brown@asciidocsmith.com"
    }
  }
]

# ingest new data
PUT /test_user_lookup/_doc/1?pipeline=user_lookup
{
  "email": "mardy.brown@asciidocsmith.com"
}

# check result
GET test_user_lookup/_search
```


## 4. Security

### 4.2 Elasticsearch Security Setup

#### Enable Elasticsearch Security in Elasticsearch

- 為了避免進入 Production Mode，先使用單機
- 為了避免 8.0 最新的自動設定 Security 的流程，我們先啟動一次關閉 Security，讓 Cluster 先初始化

```
./bin/elasticsearch -E xpack.security.enabled=false
```

- 接著我們重新啟動，這次把 `security.enabled` 打開。
- 如果是 8.0 預設會打開，只要不要加啟動時的參數即可。
- 如果是 7.x 版，要在 `elasticsearch.yml` 設定打啟。

```
xpack.security.enabled: true
```

- 這時啟動過就會自動在 config 路徑產生 keystore。
- (如果啟動前就想手動產生，可以使用以下指令)
  - create keystore to generate `keystore.seed` (default password in es)
  ```
  ./bin/elasticsearch-keystore create
  ```

- 接下來查看預設 keystore 的內容。

```
./bin/elasticsearch-keystore list
./bin/elasticsearch-keystore show keystore.seed
```

- setup default password in `bootstrap.password` in keystore (optional)

```
./bin/elasticsearch-keystore add bootstrap.password
```

- 需要重新啟動 elasticsearch，載入 keystore，讓密碼生效

- 接著也可以使用 elasticsearch-reset-password 來修改密碼

```
./bin/elasticsearch-reset-password -u elastic
```

#### Setup Kibana Credentials

- 先在 elasticsearch 建立 `kibana_system` 帳號

```
./bin/elasticsearch-reset-password -u kibana_system
```

- setup password in keystore

```
./bin/kibana-keystore create
./bin/kibana-keystore add elasticsearch.password
```

- setup username in kibana.yml
```
elasticsearch.username: "kibana_system"
```

- start Kibana

#### Enable TLS for ES transport(TCP) communication

- create ca
```
./bin/elasticsearch-certutil ca
```

- create certificate for TLS
```
./bin/elasticsearch-certutil cert --ca elastic-stack-ca.p12
```

- copy elastic-certificates.p12 in ES's config folder on each ES nodes.

- add settings below in `elasticsearch.yml`

```
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate 
xpack.security.transport.ssl.client_authentication: required
xpack.security.transport.ssl.keystore.path: elastic-certificates.p12
xpack.security.transport.ssl.truststore.path: elastic-certificates.p12
```

- setup the password of certificate in keystore on each ES nodes.

```
./bin/elasticsearch-keystore add xpack.security.transport.ssl.keystore.secure_password
./bin/elasticsearch-keystore add xpack.security.transport.ssl.truststore.secure_password
```

#### Enable TLS for ES HTTP communication

- generate http

```
./bin/elasticsearch-certutil http

# Use an existing CA? [y/N]y
```

- unzip `elasticsearch-ssl-http.zip`
- copy `elasticsearch/http.p12` in ES' config folder on each ES nodes.
- copy `kibana/elasticsearch-ca.pem` in Kibana's config folder.
- add settings below in `elasticsearch.yml`

```
xpack.security.http.ssl.enabled: true
xpack.security.http.ssl.keystore.path: http.p12
```

- setup the password of certificate in keystore on each ES nodes.

```
./bin/elasticsearch-keystore add xpack.security.http.ssl.keystore.secure_password
```

- modify `kibana.yml` to trust CA and access ES via HTTPS

```
elasticsearch.ssl.certificateAuthorities: $KBN_PATH_CONF/elasticsearch-ca.pem

elasticsearch.hosts: https://<your_elasticsearch_host>:9200
```

#### 練習： 建立安全的 Cluster

- 直接使用 8.0 auto configured security 啟動新 node
- 注意: 不要設定其他 transport, discovery 等設定，以免啟用 production mode

```
cluster.name: secure-cluster
node.name: node-1
```

- 透過 console 的 enrollment token 啟動第二台 node 與 kibana

- 建立一組新的 enrollment token

```
bin/elasticsearch-create-enrollment-token -s node
```

- 將第一個 node 的 transport 對外開放，修改 `elasticsearch.yml`

```
transport.host: [_local_, _site_]
```

- 重啟第一台 node

- 讓第三台 node 啟動

```
bin/elasticsearch -E cluster.name=secure-cluster -E node.name=node-2 --enrollment-token <token>
```

### 4.3 Role-Based Access Control

#### 練習: 依照 e-commerce 客服部需求，建立 RBAC

1. create new space - Customer Support 
with previliges below
 - Kibana Discover

2. create role - customer_support

- indices: kibana_sample_data_ecommerce
- privileges: read

- Kibana privileges: Discover(All)

3. create user - joe

- assigne role: customer_support

4. 進階需求.... (要 License)

- 開啟後可 grant for `*` but deny for `products.min_price`.


### 4.4 Snapshot & Restore

#### Shapsnot Repository

- 使用 3 nodes cluster.
- add `path.repo` in `elasticsearch.yml` on node 1 & 2. (not node 3)

```
path.repo: ["/var/tmp/elastic"]

```

- restart all nodes.

- 使用 kibana / Stack Management / Snapshot and Restore 建立 Repository

- 使用 verify repository 的功能，可以發現 node3 發生錯誤

- 再將 node 3 加入 repo 並重啟。

- 重試 verify repository

#### 建立 Snapshot 

- 使用 kibana sample data

- 在 kibana / Stack Management / Snapshot and Restore 建立 Snapshot Policy

- 最短 15 分鐘執行一次

```
0 0/15 * * * ?
```

#### 練習：替 Kibana Sample Data 建立備份策略

- 依照步驟在 Kibana 上操作。



## 3. 資料生命週期管理 (Data Lifecycle Management)

### 3.2 ILM 

#### Rollover API

```
# ----- Preparation -----
# PUT <ro-{now/d}-000001>
PUT %3Cro-%7Bnow%2Fd%7D-000001%3E
{
  "aliases": {
    "ro": {
      "is_write_index": true
    }
  }
}

GET _alias/ro
GET ro/_search

# ----- Rollover -----
# first try
POST ro/_rollover
{
  "conditions": {
    "max_age": "5m",
    "max_docs": 10,
    "max_primary_shard_size": "1mb"
  }
}

# import data
POST _reindex
{
  "source": {
    "index": "top_rated_movies"
  },
  "dest": {
    "index": "ro"
  },
  "script": {
    "source": "ctx._id=null",
    "lang": "painless"
  }
}

# second try, meet criteria and perform rollover
POST ro/_rollover
{
  "conditions": {
    "max_age": "5m",
    "max_docs": 10,
    "max_primary_shard_size": "1mb"
  }
}

# check index & alias status
GET _alias/ro

```

#### Shrink API

```
# 建立 shrink_v1 index & alias
PUT shrink_v1
{
  "settings": {
    "number_of_shards": 8
  }, 
  "aliases": {
    "shrink": {
      "is_write_index": true
    }
  }
}

# 產生假資料 (多跑幾次)
POST _reindex
{
  "source": {
    "index": "top_rated_movies"
  },
  "dest": {
    "index": "shrink_v1"
  },
  "script": {
    "source": "ctx._id=null",
    "lang": "painless"
  }
}

# 查看資料
GET shrink/_search

# 非因數不能使用
POST shrink_v1/_shrink/shrink_v2
 {
   "settings": {
     "index.number_of_shards": 3,
     "index.codec": "best_compression"
   },
   "aliases": {
     "shrink": {}
   }
}

# 將 index 設為唯讀
PUT shrink_v1/_settings
{
  "index.blocks.write": true
}

# 執行 shrink (8->4)
POST shrink_v1/_shrink/shrink_v2
 {
   "settings": {
     "index.number_of_shards": 4,
     "index.codec": "best_compression"
   },
   "aliases": {
     "shrink": {}
   }
}

# 執行 shrink (8->2)
POST shrink_v1/_shrink/shrink_v3
 {
   "settings": {
     "index.number_of_shards": 2,
     "index.codec": "best_compression"
   },
   "aliases": {
     "shrink": {}
   }
}

# 執行 shrink (8->1)
POST shrink_v1/_shrink/shrink_v4
 {
   "settings": {
     "index.number_of_shards": 1,
     "index.codec": "best_compression"
   },
   "aliases": {
     "shrink": {}
   }
}

# 查看結果
GET _cat/indices/shrink*?v
GET _cat/segments/shrink*?v&s=index

# 清理資料
# DELETE shrink*

```

#### Force Merge

```
POST shrink_v4/_forcemerge?max_num_segments=1
```

#### Custom Allocation

- add `node.attr` in `elasticsearch.yml`

```
# node-1
node.attr.rack: r1
node.attr.pet: cat

# node-2
node.attr.rack: r2
node.attr.pet: dog
```

- restart ES & check node attributes

```
GET _cat/nodeattrs?v
```

- create index w/ `index.routing.allocation` settings.

```

# create index
PUT attr_test
{
  "settings": {
    "number_of_shards": 5, 
    "number_of_replicas": 1, 
    "index.routing.allocation.include.rack": "r1,r2",
    "index.routing.allocation.exclude.pet": "dog"
  }
}

GET _cat/shards/attr_test?v

GET _cluster/allocation/explain

# not working
PUT attr_test/_settings
{
  "index.routing.allocation.include.rack": "r1,r2"
}

# because attributes have not been removed
GET attr_test/_settings?include_defaults=true&filter_path=**.routing.**

PUT attr_test/_settings
{
  "index.routing.allocation.include.rack": "r1,r2",
  "index.routing.allocation.exclude.pet": null
}

GET _cat/shards/attr_test?v

# [備用補充] 如果要反向的話，要手動移掉已分派好的 shards

POST /_cluster/reroute
{
  "commands": [
    {
      "cancel": {
        "index": "attr_test",
        "shard": 4,
        "node": "node-2"
      }
    }
  ]
}

```


#### Freeze

```
# import data
POST _reindex
{
  "source": {
    "index": "top_rated_movies"
  },
  "dest": {
    "index": "freeze"
  },
  "script": {
    "source": "ctx._id=null",
    "lang": "painless"
  }
}

GET freeze/_search

POST /freeze/_freeze

# after freezed index, cannot search data
GET freeze/_search


# unfreeze
POST freeze/_unfreeze

```

- how to search frozen index

```
# Kibana: Stack Management > Advanced Settings > Search in frozen indices

# add ignore_throttled
GET freeze/_search?ignore_throttled=false
```


#### Searchable Snapshot

##### Prepare Repository for searchable snapshot

- add `path.repo` in `elasticsearch.yml` on each node.

```
path.repo: ["/var/tmp/elastic"]

```

- restart all nodes.

##### Create Searchable Snapshot on Kibana

- go to kibana > stack management > data > snapshot and restore > repositorys to register new repository.


- mount searchable snapshot with fully mounted

```
POST /_snapshot/demo/daily-snapshot-2021.10.20-aq4f2xodq7efc8vd4iswya/_mount?wait_for_completion=true
{
  "index": "movies", 
  "renamed_index": "ss_movies", 
  "index_settings": { 
    "index.number_of_replicas": 0
  }
}
```

- search from searchable snapshot

```
GET ss_movies/_search
```

- we can also reindex from searchable snapshot

```
POST _reindex
{
  "source": {
    "index": "ss_movies"
  },
  "dest": {
    "index": "movies"
  }
}
```

- mount searchable snapshot with partial mounted

```
DELETE ss_movies

POST /_snapshot/demo/daily-snapshot-2021.10.20-aq4f2xodq7efc8vd4iswya/_mount?wait_for_completion=true&storage=shared_cache
{
  "index": "movies", 
  "renamed_index": "ss_movies", 
  "index_settings": { 
    "index.number_of_replicas": 0
  }
}
```

- query will failed due to no available shared cache

```
GET ss_movies/_search
```

- update `elasticsearch.yml` to setup shared cache

```
xpack.searchable.snapshot.shared_cache.size: 10MB
```

- after restart ES, we can search now.

```
GET ss_movies/_search
```

- we can also check cache stats of searchable snapshot

```
GET /_searchable_snapshots/cache/stats
```


#### Data Stream

```
# create data stream but failed
PUT /_data_stream/my-data-stream

# create index template w/ data stream declaration
PUT _index_template/ds-test
{
  "index_patterns": [
    "my-data-stream*"
  ],
  "data_stream": {},
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1
    }
  }
}

# this step is optional
PUT /_data_stream/my-data-stream

GET my-data-stream/_settings

# must declare op_type=create
PUT my-data-stream/_doc/1
{}

# must provide timestamp
PUT my-data-stream/_doc/1?op_type=create
{}

PUT my-data-stream/_doc/1?op_type=create
{
  "@timestamp": "2021-10-20T00:00:00"
}

# search data
GET my-data-stream/_search

# unable to delete backing index
DELETE .ds-my-data-stream-2021.10.15-000001

# delete data stream
DELETE _data_stream/my-data-stream

```

#### Demo:Create ILM

##### Create ILM on Kibana

1. create demo-ilm

2. Hot

- Rollover on 10 docs
- enable Force Merge: 1 segment only
- Shrink to 1 shard
- Read only

3. Warm

- Move data into phase when 1 minute
- Replicas: 1
- Read only

4. Cold

- Move data into phase when 2 minute
- Freeze

5. Frozen

- Move data into phase when 3 minute
- Searchable snapshot

6. Delete

- After 10 minutes

##### Create Index Template on Kibana

1. create index template

- Name: ilm-demo
- Idnex pattern: ilm-demo*
- Data stream: true
- Priority: 100
- Version: 1

- Setup Index Settings

```
{
  "number_of_shards": 8
}
```

##### Back to ILM and apply to Index Template

- apply to: ilm-demo
- alias for rollover: ilm-demo

##### Indexing Docs

```
POST ilm-demo/_doc/
{
  "@timestamp": "2021-10-20T00:00:00"
}

```

- option 2: index + alias case, we have to manual create first rolling index.

```
# manual create first rolling index (only for index w/ alias case, no need for data stream)
PUT joe-test-000001
{
  "aliases": {
    "joe-test": {
      "is_write_index": true
    }
  }
}
```

##### Setup ILM Poll Interval for Demo

```
# ILM related settings: https://www.elastic.co/guide/en/elasticsearch/reference/current/ilm-settings.html
PUT _cluster/settings
{
  "transient": {
    "indices.lifecycle.poll_interval": "10s"
  }
}

POST ilm-demo/_doc/
{
  "@timestamp": "2021-10-20T01:00:00"
}

```

##### keep indexing & check index status

```
GET ilm-demo/_ilm/explain

POST ilm-demo/_doc/?refresh=true
{
  "@timestamp": "2021-10-20T00:00:00"
}

GET ilm-demo/_search

GET _cat/indices/*demo*?v
# check for rollover (after poll interver)
# check for shrink (after 1 mins)

# after index covert to frozen index
GET ilm-demo/_search?ignore_throttled=false

# after some data moving to searchable snapshop, index will be renamed to partial-shard-xxxxx


# tips: monitor specific index
GET ilm-demo/_ilm/explain?filter_path=*.*003.*
GET .*demo*008/_search

GET _cat/segments?index=*demo*&v
```

### 3.3 Rollup & Transform

#### Demo: E-Commerce 每日訂單報表

- 先在 Kibana 建立 Rollup Job 並執行，等 1 分鐘執行完成。
- latency 設定 30s
- interval 設定 30s

```
# 試一個失敗的例子
POST daily_rollup_ecommerce/_rollup_search
{
  "size": 0,
  "aggs": {
    "product_summary": {
      "date_histogram": {
        "field": "order_date",
        "fixed_interval": "300m"
      },
      "aggs": {
        "taxful_sum": {
          "sum": {
            "field": "taxful_total_price"
          }
        },
        "taxless_sum": {
          "sum": {
            "field": "taxless_total_price"
          }
        }
      }
    }
  }
}

GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "product_summary": {
      "date_histogram": {
        "field": "order_date",
        "fixed_interval": "300m"
      },
      "aggs": {
        "taxful_sum": {
          "sum": {
            "field": "taxful_total_price"
          }
        },
        "taxless_sum": {
          "sum": {
            "field": "taxless_total_price"
          }
        }
      }
    }
  }
}

# 要使用 category terms，這樣才和 rollup 定義的一樣 
POST daily_rollup_ecommerce/_rollup_search
{
  "size": 0,
  "aggs": {
    "product_summary": {
      "date_histogram": {
        "field": "order_date",
        "fixed_interval": "300m"
      },
      "aggs": {
        "category": {
          "terms": {
            "field": "category.keyword",
            "size": 10
          },
          "aggs": {
            "taxful_sum": {
              "sum": {
                "field": "taxful_total_price"
              }
            },
            "taxless_sum": {
              "sum": {
                "field": "taxless_total_price"
              }
            }
          }
        }
      }
    }
  }
}

GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "product_summary": {
      "date_histogram": {
        "field": "order_date",
        "fixed_interval": "300m"
      },
      "aggs": {
        "category": {
          "terms": {
            "field": "category.keyword",
            "size": 10
          },
          "aggs": {
            "taxful_sum": {
              "sum": {
                "field": "taxful_total_price"
              }
            },
            "taxless_sum": {
              "sum": {
                "field": "taxless_total_price"
              }
            }
          }
        }
      }
    }
  }
}

# 甚至合併 index 一起查詢，結果是會被 deduplicate 的
POST daily_rollup_ecommerce,kibana_sample_data_ecommerce/_rollup_search
{
  "size": 0,
  "aggs": {
    "product_summary": {
      "date_histogram": {
        "field": "order_date",
        "fixed_interval": "300m"
      },
      "aggs": {
        "taxful_sum": {
          "sum": {
            "field": "taxful_total_price"
          }
        },
        "taxless_sum": {
          "sum": {
            "field": "taxless_total_price"
          }
        }
      }
    }
  }
}

```

#### Demo: Transform - `pivot`

- 示範使用 Kibana 操作

```
PUT _transform/ecommerce_transform1
{
  "source": {
    "index": "kibana_sample_data_ecommerce",
    "query": {
      "term": {
        "geoip.continent_name": {
          "value": "Asia"
        }
      }
    }
  },
  "pivot": {
    "group_by": {
      "customer_id": {
        "terms": {
          "field": "customer_id"
        }
      }
    },
    "aggregations": {
      "max_price": {
        "max": {
          "field": "taxful_total_price"
        }
      }
    }
  },
  "description": "Maximum priced ecommerce data by customer_id in Asia",
  "dest": {
    "index": "kibana_sample_data_ecommerce_transform1",
    "pipeline": "add_timestamp_pipeline"
  },
  "frequency": "5m",
  "sync": {
    "time": {
      "field": "order_date",
      "delay": "60s"
    }
  },
  "retention_policy": {
    "time": {
      "field": "order_date",
      "max_age": "30d"
    }
  }
}
```

#### Demo: Transform - `latest`

```
PUT _transform/ecommerce_transform2
{
  "source": {
    "index": "kibana_sample_data_ecommerce"
  },
  "latest": {
    "unique_key": ["customer_id"],
    "sort": "order_date"
  },
  "description": "Latest order for each customer",
  "dest": {
    "index": "kibana_sample_data_ecommerce_transform2"
  },
  "frequency": "5m",
  "sync": {
    "time": {
      "field": "order_date",
      "delay": "60s"
    }
  }
}
```

#### (備用) 另一個例子

- Latest Demo

```
PUT _transform/demo-transform-ecommerce
{
  "source": {
    "index": [
      "kibana_sample_data_ecommerce"
    ]
  },
  "latest": {
    "unique_key": [
      "order_id"
    ],
    "sort": "order_date"
  },
  "description": "demo",
  "frequency": "1m",
  "dest": {
    "index": "demo-transform-ecommerce"
  },
  "sync": {
    "time": {
      "field": "order_date",
      "delay": "10s"
    }
  },
  "retention_policy": {
    "time": {
      "field": "order_date",
      "max_age": "120s"
    }
  },
  "settings": {
    "max_page_search_size": 500
  }
}

```

- Pivot Demo

```
PUT _transform/demo-transform-aggs-ecommerce
{
  "source": {
    "index": [
      "kibana_sample_data_ecommerce"
    ]
  },
  "pivot": {
    "group_by": {
      "category": {
        "terms": {
          "field": "category.keyword"
        }
      },
      "customer_gender": {
        "terms": {
          "field": "customer_gender"
        }
      }
    },
    "aggregations": {
      "taxful_total_price.sum": {
        "sum": {
          "field": "taxful_total_price"
        }
      },
      "taxless_total_price.sum": {
        "sum": {
          "field": "taxless_total_price"
        }
      }
    }
  },
  "description": "demo",
  "frequency": "1m",
  "dest": {
    "index": "demo-transform-aggs-ecommerce"
  },
  "sync": {
    "time": {
      "field": "order_date",
      "delay": "60s"
    }
  },
  "retention_policy": {
    "time": {
      "field": "order_date",
      "max_age": "120s"
    }
  },
  "settings": {
    "max_page_search_size": 500
  }
}

```

## 6. 效能最佳化

### JVM Heap Usage

#### 如何查看 Cluster Cache 的狀態

```
# Fielddata 的狀態
GET /_cat/nodes?v&h=name,fielddataMemory,fielddataEvictions

# Fielddata Circuit Breaker 狀態
GET /_nodes/stats/breaker?filter_path=nodes.*.breakers.fielddata

# Query Cache 與 Request Cache
GET /_cat/nodes?v&h=name,queryCacheMemory,queryCacheEvictions,requestCacheMemory,requestCacheHitCount,request_cache.miss_count

# Segments, Fielddata, Query Cache, Request Cache 一覽
GET /_cat/nodes?v&h=name,port,segments.memory,segments.index_writer_memory,fielddata.memory_size,query_cache.memory_size,request_cache.memory_size
```

#### Filter Cache

```
# 查看 filter cache hit rate.
GET /_nodes/stats/indices/query_cache?human
```

## 7. 正式環境的運維及管理技巧

### 7.2 Elasticsearch Monitoring

#### Stats APIs

```
# Cluster stats
GET _cluster/stats

# Node Stats
GET _nodes/stats

# Index Stats
GET kibana_*/_stats


```

#### Slow log

```
PUT /test/_settings
{
  "index.indexing.slowlog": {
    "threshold.index.warn": "10s",
    "threshold.index.info": "5s",
    "threshold.index.debug": "2s",
    "threshold.index.trace": "500ms",
    "source": "1000" 
  },
  "index.search.slowlog.threshold": {
    "query.warn": "10s",
    "query.info": "5s",
    "query.debug": "2s",
    "query.trace": "500ms",
    "fetch.warn": "10s",
    "fetch.info": "5s",
    "fetch.debug": "2s",
    "fetch.trace": "500ms"
  }
}

```

#### Metricbeat for collecting ES metrics

- Init Metricbeat

```
metricbeat modules enable elasticsearch-xpack
```

- add all nodes hosts in modules' config 

```
output.elasticsearch:
  hosts: ["http://localhost:9200", "http://localhost:9201", "http://localhost:9202"]
  # Optional protocol and basic auth credentials.
  #protocol: "https"
  #username: "elastic"
  #password: "changeme"
```

- start metricbeat

```
sudo chown root metricbeat.yml 
# 順便給預設的 system module 權限
sudo chown root modules.d/system.yml 
sudo chown root modules.d/elasticsearch-xpack.yml 
sudo ./metricbeat -e
```


#### Filebeat for collecting ES logs

- Init Filebeat

```
./filebeat setup -e
./filebeat modules enable elasticsearch
```

- Modify the config of elasticsearch module at `<FILEBEAT_PATH>/modules.d/elasticsearch.yml`

```
# Module: elasticsearch
# Docs: https://www.elastic.co/guide/en/beats/filebeat/8.0/filebeat-module-elasticsearch.html

- module: elasticsearch
  # Server log
  server:
    enabled: true

    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    var.paths:
      - /Users/joecwu/Training/elasticsearch-*/logs*/*_server.json

  gc:
    enabled: true
    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    var.paths:
      - /Users/joecwu/Training/elasticsearch-*/logs*/gc.log.[0-9]*
      - /Users/joecwu/Training/elasticsearch-*/logs*/gc.log

  audit:
    enabled: true
    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    var.paths:
      - /Users/joecwu/Training/elasticsearch-*/logs*/*_audit.json

  slowlog:
    enabled: true
    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    var.paths:
      - /Users/joecwu/Training/elasticsearch-*/logs*/*_index_search_slowlog.json
      - /Users/joecwu/Training/elasticsearch-*/logs*/*_index_indexing_slowlog.json

  deprecation:
    enabled: true
    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    var.paths:
      - /Users/joecwu/Training/elasticsearch-*/logs*/*_deprecation.json
```

- Start Filebeat.

```
./filebeat -e
```

#### Metricbeat for collecting beats metrics

```
./metricbeat modules enable beat-xpack
```

- setup HTTP endpoints in metricbeat.yml

```
http.enabled: true
http.port: 5066
```

- setup HTTP endpoints in filebeat.yml

```
http.enabled: true
http.port: 5067
```

- add metricbeat & filebeat endpoints in ./modules.d/beat-xpack.yml

```
# Module: beat
# Docs: https://www.elastic.co/guide/en/beats/metricbeat/master/metricbeat-module-beat.html

- module: beat
  xpack.enabled: true
  period: 10s
  hosts: ["http://localhost:5066", "http://localhost:5067"]
  #username: "user"
  #password: "secret"
```

- grant root permission

```
sudo chown root modules.d/beat-xpack.yml 
```

- start metricbeat

```
sudo ./metricbeat -e
```

### 7.3 Circuit Breaker

```
# 查看 Circuit Breakers 的狀態
GET /_nodes/stats/breaker


# 查看 Circuit Breakers 相關的設定
GET /_cluster/settings?include_defaults=true&flat_settings&filter_path=*.*breaker*
```


### 7.4 Cluster 常見的問題與解決方式

#### CPU 飆高

```
#觀察 CPU usage
GET _cat/nodes?v=true&s=cpu:desc


#觀察 hot_threads by nodes
GET _nodes/es-node1,es-node2/hot_threads

# check long running task
GET _tasks?actions=*search&detailed

# cancel tasks
POST _tasks/oTUltX4IQMOUUVeiohTt8A:464/_cancel
```

#### Cluster 燈號變黃或紅

```
# 檢查 Unassigned Shard 的原因, 先找到哪個 Index 及哪個 Node
GET _cat/shards?v=true&h=index,shard,prirep,state,node,unassigned.reason&s=state&v

# 使用 Cluster Allocation Explain API 查看細節
GET _cluster/allocation/explain?filter_path=index,node_allocation_decisions.node_name,node_allocation_decisions.deciders.*
{
  "index": "my-index",
  "shard": 0,
  "primary": false,
  "current_node": "my-node"
}

# 真的不行時，至少救回部份資料
POST _cluster/reroute
{
  "commands": [
    {
      "allocate_empty_primary": {
        "index": "my-index",
        "shard": 0,
        "node": "my-node",
        "accept_data_loss": "true"
      }
    }
  ]
}

```

#### 429 Error

```
# 檢查每個 thread pool 中的 rejected tasks 數量
GET /_cat/thread_pool?v=true&h=node_name,id,name,active,rejected,completed
```

#### 堆太多 Task 導致 Cluster 變不健康

```
# 查看 Long Running Tasks
GET /_tasks?filter_path=nodes.*.tasks

# 確認 Thread Pool 狀態
GET /_cat/thread_pool?v&s=t,n&h=type,name,node_name,active,queue,rejected,completed

# 確認是否有 Long Running Tasks 成為 Hot Thread
GET /_nodes/hot_threads
```


