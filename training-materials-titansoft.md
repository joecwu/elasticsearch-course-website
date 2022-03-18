# Training Material Extension for Titansoft

## Index Alias

### Add alias with date math
```
PUT movies

POST _aliases
{
  "actions": [
    {
      "add": {
        "index": "movies",
        "alias": "<movies-{now{yyyy.MM.dd|+08:00}}>"
      }
    }
  ]
}
```

### Get alias

```
GET _alias/movies*
```

### 情境 1 - 提供單一名稱，查詢時對照到多個 Index，寫入時指定其中一個 Index

```
PUT <test-{now-2d}>
PUT <test-{now-1d}>
PUT <test-{now}>

POST _aliases
{
  "actions": [
    {
      "add": {
        "index": "test-*",
        "alias": "test"
      }
    },
    {
      "add": {
        "index": "<test-{now}>",
        "alias": "test",
        "is_write_index": true
      }
    }
  ]
}

GET test*/_alias
```

### 情境 2 - 搭配 Filter 做到權限控管、商業邏輯封裝的使用。
```
POST _aliases
{
  "actions": [
    {
      "add": {
        "index": "movies",
        "alias": "crime-movies",
        "filter": {
          "bool": {
            "filter": {
              "term": {
                "genres.keyword": "Crime"
              }
            }
          }
        }
      }
    }
  ]
}

GET crime-movies/_search
```

### 情境 3 - 避免 Client 端直接存取原始 Index，支援 Index 名稱上的版控

```
PUT drama_v1

POST _aliases
{
  "actions": [
    {
      "add": {
        "index": "drama_v1",
        "alias": "drama"
      }
    }
  ]
}
```

### 情境 4 - 做到 blue/green deployment

```
PUT drama_v2

## option1: keep drama_v1

POST _aliases
{
  "actions": [
    {
      "remove": {
        "index": "drama_v1",
        "alias": "drama"
      }
    },
    {
      "add": {
        "index": "drama_v2",
        "alias": "drama"
      }
    }
  ]
}

## option2: remove drama_v1 directly

POST _aliases
{
  "actions": [
    {
      "add": {
        "index": "drama_v2",
        "alias": "drama"
      }
    },
    {
      "remove_index": {
        "index": "drama_v1"
      }
    }
  ]
}

GET drama*/_alias
```

## Index Template


### Component Template


core + audit_info

```
PUT _component_template/core-mapping
{
  "version": 1,
  "template": {
    "mappings": {
      "_source": {
        "enabled": true,
        "excludes": [
          "message"
        ]
      },
      "properties": {
        "@timestamp": {
          "type": "date"
        },
        "audit_info": {
          "type": "object",
          "properties": {
            "creator": {
              "type": "keyword"
            },
            "create_date": {
              "type": "date"
            },
            "modifier": {
              "type": "keyword"
            },
            "last_modified_date": {
              "type": "date"
            }
          }
        }
      }
    }
  },
  "_meta": {
    "author": "joe",
    "description": "demo component template",
    "last_updated_time": "2021-10-10"
  }
}

PUT _component_template/core-setting
{
  "version": 1,
  "template": {
    "settings": {
      "number_of_shards": 2,
      "number_of_replicas": 1
    }
  },
  "_meta": {
    "author": "joe",
    "description": "demo component template",
    "last_updated_time": "2021-10-10"
  }
}

GET _component_template/core*


```


### Index Template

```
PUT _index_template/service-logs
{
  "version": 1,
  "priority": 100,
  "template": {
    "aliases": {
      "service-logs": {}
    }
  },
  "index_patterns": [
    "service-logs*"
  ],
  "composed_of": [
    "core-mapping",
    "core-setting"
  ],
  "_meta": {
    "author": "joe",
    "last_modified_date": "2021-10-17"
  }
}
```

### Simulate Index

```
POST _index_template/_simulate_index/service-logs-2021.10.17

```


### Simulate Template

```
POST _index_template/_simulate/service-logs


```


### Test Data

```
PUT service-logs-2021.10.16/_doc/1
{
  "@timestamp": "2021-10-16T08:00:00",
  "message": "this is a test message 1",
  "service_type": "web-server",
  "audit_info": {
    "creator": "joe",
    "create_date": "2021-10-10T08:00:00"
  }
}

GET service-logs
GET service-logs/_search

PUT service-logs/_doc/2
{
  "@timestamp": "2021-10-16T08:00:00",
  "message": "this is a test message 2",
  "service_type": "web-server",
  "audit_info": {
    "creator": "joe",
    "create_date": "2021-10-10T08:10:00"
  }
}


PUT service-logs-2021.10.17/_doc/3
{
  "@timestamp": "2021-10-17T08:00:00",
  "message": "this is a test message 3",
  "service_type": "web-server",
  "audit_info": {
    "creator": "joe",
    "create_date": "2021-10-10T08:00:00"
  }
}

# 失敗，超過一個 index 綁在 alias 上面，alias 沒有宣告 is_write_index
PUT service-logs/_doc/4
{
  "@timestamp": "2021-10-17T08:00:00",
  "message": "this is a test message 4",
  "service_type": "web-server",
  "audit_info": {
    "creator": "joe",
    "create_date": "2021-10-10T08:10:00"
  }
}




```


### 情境題 - 客服部門只能存取最近一年的資料，其他人能正常存取全部資料

```
PUT _component_template/audit-logs_settings
{
  "version": 1,
  "template": {
    "settings": {
      "index.auto_expand_replicas": "1-3"
    }
  }
}

PUT _component_template/audit-logs_mappings
{
  "version": 1,
  "template": {
    "mappings": {
      "properties": {
        "@timestamp": {
          "type": "date"
        }
      }
    }
  }
}

PUT _component_template/audit-logs_cs_alias
{
  "version": 1,
  "template": {
    "aliases": {
      "cs-{index}": {
        "index": "audit-logs*",
        "filter": {
          "bool": {
            "filter": {
              "range": {
                "@timestamp": {
                  "gte": "now-1y"
                }
              }
            }
          }
        }
      }
    }
  }
}

PUT _index_template/audit-logs
{
  "index_patterns": [
    "audit-logs*"
  ],
  "template": {
    "mappings": {},
    "settings": {},
    "aliases": {}
  },
  "priority": 100,
  "composed_of": [ "audit-logs_settings", "audit-logs_mappings", "audit-logs_cs_alias" ]
}

PUT audit-logs-order/_doc/1
{
  "@timestamp": "2021-10-16",
  "test": 1
}


PUT audit-logs-order/_doc/2
{
  "@timestamp": "2019-10-16",
  "test": 2
}

PUT audit-logs-payment/_doc/1
{
  "@timestamp": "2019-10-16",
  "test": 123
}

GET audit-logs-order
GET audit-logs-payment

GET cs-audit-logs-order/_search
GET cs-audit-logs-payment/_search

GET audit-logs-order/_search
GET audit-logs-payment/_search

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


## Elastic Stack - Filebeat

- 下載 dataset - Apache Access Logs

- create `filebeat_user` role
```
# cluster privileges
- manage_ilm, monitor, manage_index_templates


# index privileges
- filebeat-*
- create, create_index, index, manage
```

- create `filebeat` user w/ `filebeat_user` priviledge only.

- 設定 filebeat.yml

```
- type: filestream
  enabled: true
  paths:
    - /Users/joecwu/Training/materials/filebeat/filebeat-logs/*

output.elasticsearch:
  hosts: ["localhost:9200"]
  protocol: "https"
  ssl.certificate_authorities: ["/Users/joecwu/Training/beats/filebeat-7.15.1-darwin-x86_64/elasticsearch-ca.pem"]
  username: "filebeat"
  password: "changeme"

```

- [bypass] create keystore & setup password (if needed)

```
./filebeat keystore create
./filebeat keystore add ES_PWD

```

- setup modules if needed

```
./filebeat modules enable {module_name}
```

- init kibana dashboard & ES index template

```
./filebeat setup -e
```

- start filebeat

```
./filebeat -e
```


### 收集 Elasticsearch Logs

```
# Module: elasticsearch
# Docs: https://www.elastic.co/guide/en/beats/filebeat/7.x/filebeat-module-elasticsearch.html

- module: elasticsearch
  # Server log
  server:
    enabled: true

    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    var.paths:
      - /Users/joecwu/Training/elasticsearch-*/logs/*_server.json

  gc:
    enabled: true
    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    var.paths:
      - /Users/joecwu/Training/elasticsearch-*/logs/gc.log.[0-9]*
      - /Users/joecwu/Training/elasticsearch-*/logs/gc.log

  audit:
    enabled: true
    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    var.paths:
      - /Users/joecwu/Training/elasticsearch-*/logs/*_audit.json

  slowlog:
    enabled: true
    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    var.paths:
      - /Users/joecwu/Training/elasticsearch-*/logs/*_index_search_slowlog.json
      - /Users/joecwu/Training/elasticsearch-*/logs/*_index_indexing_slowlog.json

  deprecation:
    enabled: true
    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    var.paths:
      - /Users/joecwu/Training/elasticsearch-*/logs/*_deprecation.json
```






