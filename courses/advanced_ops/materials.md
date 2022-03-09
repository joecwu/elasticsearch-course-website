# Elasticsearch 進階運維班

-----
##### Day 1
-----

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

### 關聯式資料的存取

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
















## Security

### Enable Elasticsearch Security in Elasticsearch

- add settings in `elasticsearch.yml`

```
xpack.security.enabled: true
```

- create keystore to generate `keystore.seed` (default password in es)

```
./bin/elasticsearch-keystore create
./bin/elasticsearch-setup-passwords [auto|interactive]
```

- setup default password in `bootstrap.password` in keystore (optional)

```
./bin/elasticsearch-keystore add bootstrap.password
```

- restart ES

- check security enabled by chrome

Setup Kibana

- setup password in keystore

```
./bin/kibana-keystore create
./bin/kibana-keystore add elasticsearch.password
```

- setup username in kibana.yml
```
elasticsearch.username: "kibana_system"
```

### Enable TLS for ES transport(TCP) communication

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

### Enable TLS for ES HTTP communication

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


### RBAC - Kibana Demo - basic

1. create role - customer_support

- indices: kibana_sample_data_ecommerce
- privileges: read

- Kibana privileges: Discover(All), Dashboard(Read)

2. create user - joe

- assigne role: customer_support


### RBAC - Kibana Demo - advanced w/ filter

1. create new space - Customer Support 
with previliges below
 - Kibana Discover
 - Kibana Dashboard
 - Stake Management

2. switch space to Customer Support & create index pattern
 - cs-audit-logs-*
 - kibana_sample_data_ecommerce

3. create role - customer_support

- index: kibana_sample_data_ecommerce, 
- privileges: read

- index: cs-audit-logs-*
- privileges: read

- Kibana privileges: Discover(All), Dashboard(Read)
- space: Customer support



## ILM

### Rollover API

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

### Shrink API

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

### Force Merge

```
POST shrink_v4/_forcemerge?max_num_segments=1
```

### Custom Allocation

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


### Freeze

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


### Searchable Snapshot

#### Prepare Repository for searchable snapshot

- add `path.repo` in `elasticsearch.yml` on each node.
```
path.repo: ["/var/tmp/elastic"]

```

- restart all nodes.
- 
#### Create Searchable Snapshot on Kibana

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


### Data Stream

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

### Create ILM

#### Create ILM on Kibana

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

#### Create Index Template on Kibana

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

#### Back to ILM and apply to Index Template

- apply to: ilm-demo
- alias for rollover: ilm-demo

#### Indexing Docs

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

#### Setup ILM Poll Interval for DEMO

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

#### keep indexing & check index status

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

## Ingest Pipeline

### Dissect

- also create on Kibana

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

- 可以在 kibana 直接操作

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

### uriparts

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

### Pipeline

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























### Elasticsearch Monitoring


#### Filebeat

Init Filebeat

```
./filebeat setup -e
./filebeat modules enable elasticsearch
```


Modify the config of elasticsearch module at `<FILEBEAT_PATH>/modules.d/elasticsearch.yml`

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

Start Filebeat.
```
./filebeat -e
```


