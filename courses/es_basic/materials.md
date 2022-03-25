# 喬叔的 Elasticsearch 基礎實務班 上課示範 Scripts

###### tags: `Elasticsearch 基礎實務班 Demo`

---

[TOC]

---

## ELASTICSEARCH 快速上手

### 啟用 Elasticsearch 並先關閉 X-Pack Security

於 elasticsearch 解壓縮的目錄中，執行以下指令：

```
./bin/elasticsearch -E xpack.security.enabled=false
```

Windows 執行 `elasticsearch.bat` 批次檔：

```
bin\elasticsearch.bat -E xpack.security.enabled=false
```

### 查詢 Cluster 狀態

```
GET _cat/nodes?v
```

### 啟用 Kibana

在 Kibana 解壓縮的目錄中，執行以下指令：

```
./bin/kibana
```

### Indexing documents

```
PUT /movies/_doc/1
{
  "title": "Star Wars: Episode VII – The Force Awakens",
  "director": "J.J. Abrams",
  "year": 2015
}
```

### 確認 Index Document 個數

```
GET _cat/indices?v
```

### 搜尋所有documents

```
GET _search
```


### 加入 Genres 的欄位

```
PUT /movies/_doc/1
{
  "title": "Star Wars: Episode VII – The Force Awakens",
  "director": "J.J. Abrams",
  "year": 2015,
  "Genres": ["Action", "Adventure", "Fantasy"]
}
```

### Getting document by ID

```
GET /movies/_doc/1

GET /movies/_doc/1?_source=title,director

GET /movies/_doc/1/_source
```

### Deleting document

```
DELETE /movies/_doc/1
```

### 匯入 10 筆 Movies 資料

資料來源: [課程網站 Appendix A. Datasets](https://es.joecwu.com/datasets.html) 當中的 A.1 [load movies](https://es.joecwu.com/load_movies_kibana.json)

### Search

```
GET /movies/_search

POST _search
{
  "query": {
    "match_all": {}
  }
}

POST /movies/_search
{
  "query": {
    "match_all": {}
  }
}

POST /movies/_search
{
  "query": {
    "match_all": {}
  },
  "_source": ["title","director"]
}

POST /movies/_search
{
    "query": {
        "query_string": {
           "query": "kill"
        }
    }
}

GET /movies/_search?q=kill

GET /movies/_search?q=title:kill
```

### Filter

```
POST /movies/_search
{
  "query": {
    "bool": {
      "must": {
        "query_string": {
           "fields": ["title"],
           "query": "kill"
        }
      }, 
      "filter": {
        "term": {
          "year": "2003"
        }
      }
    }
  }
}


POST /movies/_search
{
  "query": {
    "bool": { 
      "filter": {
        "term": {
          "year": "2014"
        }
      }
    }
  }
}

POST _search
{
  "query": {
    "bool": {
      "must": {
        "query_string": {
           "fields": ["title"],
           "query": "kill"
        }
      }, 
      "filter": {
        "term": {
          "year": "2003"
        }
      }
    }
  }
}

POST _search
{
  "query": {
    "bool": {
      "must": {
        "match_all": {}
      }, 
      "filter": {
        "term": {
          "year": "2014"
        }
      }
    }
  }
}
```

### Term Query 與修改 Mapping 以加入 keyword field

```
POST _search
{
  "query": {
    "term": {
      "director": "J.J. Abrams"
    }
  }
}

POST _search
{
  "query": {
    "term": {
      "director": "abrams"
    }
  }
}

POST /movies/_mapping
{
  "properties": {
    "director": {
      "type": "keyword"
    }
  }
}

POST /movies/_mapping
{
  "properties": {
     "director": {
        "type": "text",
        "fields": {
            "original": {"type": "keyword"} 
        }
     }
  }
}

PUT /movies/_doc/1
{
  "title": "Star Wars: Episode VII – The Force Awakens",
  "director": "J.J. Abrams",
  "year": 2015,
  "genres": ["Action", "Adventure", "Fantasy"]
}

POST /movies/_search
{
  "query": {
    "term": {
      "director.original": "J.J. Abrams"
    }
  }
}

GET /movies/_search
{
  "query": {
    "bool": {
      "filter": [
        {
          "term": {
            "genres.keyword": "Crime"
          }
        }
      ]
    }
  }
}

# Since 5.0 _default_ mapping for string has keyword field.
GET /movies/_mapping

```

## Data in/out

### Create Index

```
PUT /movies
{
  "settings": {
    "number_of_shards": 1
  },
  "mappings": {
    "_source": {
      "enabled": false
    },
    "properties": {
      "director": {
        "type": "text",
        "fields": {
          "original": {
            "type": "keyword"
          }
        }
      }
    }
  }
}
```

### Indexing Document with operation type

```
PUT movies/_doc/8/_create
{
  "title": "Star Wars: Episode VII – The Force Awakens",
  "director": "J.J. Abrams",
  "year": 2015,
  "Genres": [
    "Action",
    "Adventure",
    "Fantasy"
  ]
}

PUT movies/_doc/8?op_type=create
{
  "title": "Star Wars: Episode VII – The Force Awakens",
  "director": "J.J. Abrams",
  "year": 2015,
  "Genres": [
    "Action",
    "Adventure",
    "Fantasy"
  ]
}
```

### Get API

```
GET /movies/_doc/1
```

### Exists API

```
HEAD /movies/_doc/1
```


### Delete API

```
DELETE /movies/_doc/1
```

### Delete by Query API

```
POST /movies/_delete_by_query
{
  "query": { "match_all": {} } 
}
```

### Update API

```
POST /movies/_update/1
{
  "doc":{
    "likes": 123
  }
}
```

### Multi Get API

```
GET /_mget
{
  "docs": [
    {
      "_index": "movies",
      "_id": "1"
    },
    {
      "_index": "movies",
      "_id": "2"
    }
  ]
}

GET /movies/_mget
{ 
  "ids": ["1","2"]
}
```

### Bulk API

```
curl -i -XPUT http://localhost:9200/_bulk -H 'Content-Type: application/json' --data-binary @top_rated.json

curl -i -XPUT http://localhost:9200/shakespeare/_bulk -H 'Content-Type: application/x-ndjson' --data-binary @shakespeare.json

or

PUT /_bulk
{{content of top_rated.json}}
```

### Search API

```
GET /movies/_search?q=star

GET /movies/_search?q=star+OR+kill

GET /movies/_search?q=(star+OR+kill)+AND+year:[2003+TO+*]

POST /movies/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "query_string": {
            "query": "star OR kill"
          }
        }
      ],
      "filter": {
        "range": {
          "year": {
            "gte": 2003
          }
        }
      }
    }
  }
}

# Enable sort & profile
POST /movies/_search
{
  "from": 0, 
  "size": 20, 
  "sort": [
    {
      "year": {
        "order": "asc"
      }
    }
  ], 
  "profile": true,
  "query": {
    "bool": {
      "must": [
        {
          "match": {
            "title": {
              "query": "star kill",
              "operator": "or"
            }
          }
        }
      ],
      "filter": {
        "range": {
          "year": {
            "gte": 2003
          }
        }
      }
    }
  }
}

```

### Index Alias

#### Add alias with date math
```
# PUT <movies-{now{yyyy.MM.dd|+0800}}>
# URLEncoded 完整: PUT %3Cmovies-%7Bnow%7Byyyy.MM.dd%7C%2B0800%7D%7D%3E
# 只針對 `+` encode
PUT <movies-{now{yyyy.MM.dd|%2B0800}}>

POST _aliases
{
  "actions": [
    {
      "add": {
        "index": "<movies-{now{yyyy.MM.dd|+0800}}>",
        "alias": "movies"
      }
    }
  ]
}
```

#### Get alias

```
GET _alias/movies*
```

#### 情境 1 - 提供單一名稱，查詢時對照到多個 Index，寫入時指定其中一個 Index

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



## Elasticsearch Under the Hood


### 分散式架構對相關性計分的影響

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

使用 `dfs_query_then_fetch` search type

```
GET score/_search?q=apple&search_type=dfs_query_then_fetch
```

(補充)查看計分的細節

```
GET score/_search?q=apple&explain=true
```


### Elasticsearch Flush

```
POST /index1/_flush
```

### Elasticsearch Refresh

```
POST /index1/_refresh

# modify index refresh interval
PUT /index1/_settings
{
  "index.refresh_interval": "60s"
}
```

### Segments
```
  GET /_cat/segments?v

  GET /index/_segments

  POST /_forcemerge?max_num_segments=1
```


---

## Text Analysis

### Analyze API 示範

```
POST /_analyze
{
  "tokenizer": "keyword", 
  "text": "New York"
}

POST /_analyze
{
  "tokenizer": "keyword", 
  "filter": [ "lowercase" ],
  "text": "New York"
}

POST /_analyze
{
  "tokenizer": "whitespace", 
  "filter": [ "lowercase", "stop" ],
  "text": "The quick fox jumped"
}

POST /_analyze
{
  "tokenizer": "keyword", 
  "filter": [ "lowercase" ],
  "text": "this is a <b>HTML</b> document"
}

POST /_analyze
{
  "tokenizer": "keyword", 
  "filter": [ "lowercase" ],
  "char_filter": [ "html_strip" ],
  "text": "this is a <b>HTML</b> document"
}
```

### 自訂 Analyzer

```
PUT /courses
{
  "settings": {
    "index": {
      "analysis": {
        "analyzer": {
          "my_analyzer": {
            "tokenizer": "whitespace",
            "filter": ["lowercase", "stop", "snowball"]
          }
        }
      }
    }
  }
}

POST /courses/_analyze
{ 
  "analyzer": "my_analyzer",
  "text": "The quick fox jumped"
}
```

### 練習自訂 Analyzer 指定給某個欄位

```
PUT /courses
{
  "settings": {
    "index": {
      "analysis": {
        "analyzer": {
          "my_analyzer": {
            "tokenizer": "whitespace",
            "filter": ["lowercase", "stop", "snowball"]
          }
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "title": {
        "type": "text",
        "analyzer": "my_analyzer"
      }
    }
  }
}

POST /courses/_analyze
{
  "field": "title", 
  "text": "test for customized analyzer"
}
```

### 修改現有的 Index Setting，加入 suggester Analyzer

```
# Update Existing Index Setting & edgeNGram test
POST /courses/_close
PUT /courses/_settings
{
  "settings": {
    "index": {
      "analysis": {
        "analyzer": {
          "custom_analyzer": {
            "tokenizer": "lowercase",
            "filter": [
              "stop",
              "snowball"
            ]
          },
          "suggester": {
            "tokenizer": "lowercase",
            "filter": [
              "4edgeNGram"
            ]
          }
        },
        "filter": {
          "4edgeNGram": {
            "type": "edge_ngram",
            "min_gram": 2,
            "max_gram": 5
          }
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "title": {
        "type": "text",
        "analyzer": "custom_analyzer"
      }
    }
  }
}
POST /courses/_open

POST courses/_analyze
{
  "text": "test for customized analyzer",
  "analyzer": "suggester"
}
```

### 中文斷詞

```
# Dev Tools HTTP GET w/ 中文 會有問題
POST _analyze
{
  "tokenizer": "standard", 
  "text": "蔡英文"
}

POST _analyze
{
  "tokenizer": "icu_tokenizer", 
  "text": "蔡英文"
}

POST /_analyze
{
  "tokenizer": "icu_tokenizer", 
  "text": "蔡英文跟柯文哲去基隆廟口夜市吃宵夜"
}

POST /_analyze
{
  "analyzer": "smartcn", 
  "text": "蔡英文跟柯文哲去基隆廟口夜市吃宵夜"
}

PUT /chinese
{
  "mappings": {
    "properties": {
      "title": {
        "type": "text",
        "store": true,
        "index": true,
        "analyzer": "smartcn"
      },
      "body": {
        "type": "text",
        "store": true,
        "index": true,
        "analyzer": "smartcn"
      }
    }
  }
}

PUT /chinese/_doc/1
{
  "title": "基隆廟口夜市",
  "body": "蔡英文跟柯文哲去基隆廟口夜市吃宵夜"
}

PUT /chinese/_doc/2
{
  "title": "愈夜愈美",
  "body": "夜色愈夜愈美麗"
}

PUT /chinese/_doc/3
{
  "title": "英文考試",
  "body": "英文考試100分"
}

PUT /chinese/_doc/4
{
  "title": "英文考試",
  "body": "蔡小明英文考試不及格"
}

PUT /chinese/_doc/5
{
  "title": "電影導演",
  "body": "蔡明亮是一位出生於英屬砂勞越的電影導演，英文很好"
}

POST /chinese/_search
{
  "query": {
    "match": {
      "body": "夜色"
    }
  }
}

POST /chinese/_search
{
  "query": {
    "match": {
      "body": "蔡英文"
    }
  }
}
```

### pinyin 拼音 plugin

```
PUT /medcl/
{
  "settings": { 
    "index" : {
        "analysis" : {
            "analyzer" : {
                "pinyin_analyzer" : {
                    "tokenizer" : "my_pinyin"
                    }
            },
            "tokenizer" : {
                "my_pinyin" : {
                    "type" : "pinyin",
                    "keep_separate_first_letter" : false,
                    "keep_full_pinyin" : true,
                    "keep_original" : true,
                    "limit_first_letter_length" : 16,
                    "lowercase" : true,
                    "remove_duplicated_term" : true
                }
            }
        }
    }
  }
}

POST /medcl/_analyze
{
  "analyzer": "pinyin_analyzer",
  "text": "蔡英文"
}

POST /medcl/_analyze
{
  "analyzer": "pinyin_analyzer",
  "text": "菜英文"
}
```


### 自訂詞庫 IK plugin

```
Visit https://github.com/medcl/elasticsearch-analysis-ik/releases
copy link for latest zip file, e.g: https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v7.0.1/elasticsearch-analysis-ik-7.3.0.zip

bin/elasticsearch-plugin install https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v7.0.1/elasticsearch-analysis-ik-7.3.0.zip

## 設定字典檔 https://github.com/medcl/elasticsearch-analysis-ik#dictionary-configuration

add custom.dic(裡面可以放自訂的自詞，一行一個字) file under {conf}/analysis-ik/config/

修改 {conf}/analysis-ik/config/IKAnalyzer.cfg.xml 加上 custom.dic 在 ext_dict 裡面
<entry key="ext_dict">custom.dic</entry>

## 重新啟動elasticsearch

POST _analyze
{
  "analyzer": "ik_smart",
  "text": "蔡英文跟柯文哲去基隆廟口夜市吃宵夜"
}
```


#### 補充，混合 拼音 與 IK analyzer
```
PUT /chinese
{
  "settings": {
    "index": {
      "analysis": {
        "analyzer": {
          "pinyin_analyzer": {
            "tokenizer": "my_pinyin"
          }
        },
        "tokenizer": {
          "my_pinyin": {
            "type": "pinyin",
            "keep_separate_first_letter": false,
            "keep_full_pinyin": true,
            "keep_original": true,
            "limit_first_letter_length": 16,
            "lowercase": true,
            "remove_duplicated_term": true
          }
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "title": {
        "type": "text",
        "store": true,
        "index": true,
        "analyzer": "standard",
        "fields": {
          "ik": {
            "type": "text",
            "analyzer": "ik_smart"
          },
          "pinyin": {
            "type": "text",
            "analyzer": "pinyin_analyzer"
          }
        }
      },
      "body": {
        "type": "text",
        "store": true,
        "index": true,
        "analyzer": "standard",
        "fields": {
          "ik": {
            "type": "text",
            "analyzer": "ik_smart"
          },
          "pinyin": {
            "type": "text",
            "analyzer": "pinyin_analyzer"
          }
        }
      }
    }
  }
}

# Boost for difference fields
POST /chinese/_search
{
  "query": {
    "bool": {
      "should": [
        {
          "bool": {
            "must": [
              {
                "match": {
                  "body.ik": "蔡英文"
                }
              }
            ],
            "boost": 3
          }
        },
        {
          "match": {
            "body.pinyin": "蔡英文"
          }
        }
      ]
    }
  }
}

```

## Mapping 的介紹與管理方式

### Basic Mapping

```
PUT /courses
{
  "mappings": {
    "properties": {
      "id": {
        "type": ”keyword”
      },
      "title": {"type": ”text"},
      "start_date": {"type": "date"}
    }
  }
}

```

### Disable Dynamic Mapping

```
PUT /courses
{
  "mappings": {
    "dynamic": "false",
    "properties": {
      "id": {
        "type": ”keyword”
      },
        "title": {"type": ”text"},
        "start_date": {"type": "date"}
    }
  }
}

```

### Store
```
DELETE /my_index

PUT /my_index
{
  "mappings": {
    "_source": {
      "enabled": false
    },
    "properties": {
      "title": {
        "type": "text",
        "store": true
      },
      "date": {
        "type": "date",
        "store": true
      },
      "content": {
        "type": "text"
      }
    }
  }
}

PUT /my_index
{
  "mappings": {
    "_source": {
      "enabled": true,
      "excludes": ["content"]
    },
    "properties": {
      "title": {
        "type": "text"
      },
      "date": {
        "type": "date"
      },
      "content": {
        "type": "text"
      }
    }
  }
}

PUT /my_index/_doc/1
{
  "title":   "Some short title",
  "date":    "2015-01-01",
  "content": "A very long content field..."
}

GET /my_index/_doc/1

GET my_index/_search
{
  "stored_fields": [ "title", "date" ] 
}
```

### Copy To
```
PUT /copy_to
{
  "mappings": {
    "properties": {
      "first_name": {
        "type": "text",
        "copy_to": "full_name" 
      },
      "last_name": {
        "type": "text",
        "copy_to": "full_name" 
      },
      "full_name": {
        "type": "text"
      }
    }
  }
}

PUT /copy_to/_doc/1
{
  "first_name": "John",
  "last_name": "Smith"
}

GET /copy_to/_doc/_search
```

### Term Vector
```
PUT term_vector
{
  "mappings": {
    "properties": {
      "text": {
        "type":        "text",
        "term_vector": "with_positions_offsets"
      }
    }
  }
}

PUT term_vector/_doc/1
{
  "text": "Quick brown fox"
}

GET term_vector/_search
{
    "query": {
        "match": {
           "text": "brown fox"
        }
    },
    "highlight": {
        "fields": {
            "text": {}
        }
    }
}
```

### Nested Fileds
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


### Index Template

#### Component Template

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

#### Index Template

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

#### Simulate Index

```
POST _index_template/_simulate_index/service-logs-2021.10.17

```


#### Simulate Template

```
POST _index_template/_simulate/service-logs


```


#### Test Data

```
# 指定 index name，透過 index template 產生 index
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

# 透過 alias 存取
GET service-logs
GET service-logs/_search

# 透過 alias indexing document
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

# 指定新的 index，同樣透過 index template 產生 index
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

# 查看 alias 同時綁定兩個 index
GET service-logs

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

# 這時，就要使用先前介紹的 Alias API，指定 `is_write_index`

POST _aliases
{
  "actions": [
    {
      "add": {
        "index": "service-logs-2021.10.17",
        "alias": "service-logs",
        "is_write_index": true
      }
    }
  ]
}

```

#### 情境題 - 客服部門只能存取最近一年的資料，其他人能正常存取全部資料

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

## Search

### match query with `operator` and `minimum_should_match`

```
GET top_rated_movies/_search
{
  "query": {
    "match": {
      "title": {
        "operator": "and", 
        "query": "howl's castle"
      }
    }
  },
  "size": 50
}

GET top_rated_movies/_search
{
  "query": {
    "match": {
      "title": {
        "operator": "or", 
        "query": "howl's castle apple macbook",
        "minimum_should_match": 3
      }
    }
  },
  "size": 50
}
```

### match phrase query
```
GET top_rated_movies/_search
{
  "query": {
    "match_phrase": {
      "title": "howl's castle"
    }
  }
}

GET top_rated_movies/_search
{
  "query": {
    "match_phrase": {
      "title": "howl's moving castle"
    }
  }
}

GET top_rated_movies/_search
{
  "query": {
    "match_phrase": {
      "title": {
        "query": "howl's castle",
        "slop": 1
      }
    }
  }
}

GET top_rated_movies/_search
{
  "query": {
    "match_phrase": {
      "title": {
        "query": "castle moving",
        "slop": 2
      }
    }
  }
}

GET chinese/_search
{
  "query": {
    "match_phrase": {
      "body": "蔡英文"
    }
  },
  "size": 50
}
```

### range query

```
PUT test_date/_doc/1
{
  "time": "2021-07-25T23:12:13"
}

PUT test_date/_doc/2
{
  "time": "2021-07-25"
}

PUT test_date/_doc/3
{
  "time": "2021-07-25T00:00:00"
}

GET test_date/_mapping

GET test_date/_search
{
  "query": {
    "bool": {
      "filter": {
        "range": {
          "time": {
            "lt": "now+1d"
          }
        }
      }
    }
  }
}

GET test_date/_search
{
  "query": {
    "bool": {
      "filter": {
        "range": {
          "time": {
            "gt": "now/d",
            "lt": "now+1d",
            "time_zone": "+0800"
          }
        }
      }
    }
  }
}

GET test_date/_search
{
  "query": {
    "bool": {
      "filter": {
        "range": {
          "time": {
            "lt": "2021-07-25",
            "time_zone": "+0800"
          }
        }
      }
    }
  }
}
```

### fuzzy query
```
GET top_rated_movies/_search
{
    "query": {
       "fuzzy" : { 
        "title" : {
          "value": "kastla",
          "fuzziness": 2
        }
      }
  }
}

PUT fuzzy_test/_doc/1
{
  "product_name": "facebook"
}

POST fuzzy_test/_search
{
  "query": {
    "fuzzy": {
      "product_name": {
        "value": "macbook",
        "prefix_length": 0,
        "fuzziness": 2
      }
    }
  }
}
```

### Score Boosting

```
GET top_rated_movies/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "multi_match": {
            "fields": ["title", "original_title^2"], 
            "query": "city"
          }
        }
      ],
      "should": [
        {
          "range": {
            "popularity": {
              "gte": 0.3
            }
          }
        },
        {
          "range": {
            "vote_average": {
              "gte": 10,
              "boost": 10000
            }
          }
        }
      ],
      "filter": [
        {
          "range": {
            "vote_count": {
              "gte": 10
            }
          }
        }
      ]
    }
  }
}

```



### 匯入 Shakespeare
```
PUT /shakespeare
{
  "settings": {
    "number_of_shards": 5,
    "number_of_replicas": 1
  },
  "mappings": {
    "properties": {
      "type": {
        "type": "keyword"
      },
      "speaker": {
        "type": "keyword"
      },
      "play_name": {
        "type": "keyword"
      },
      "line_id": {
        "type": "integer"
      },
      "speech_number": {
        "type": "integer"
      }
    }
  }
}
```

```
curl -H 'Content-Type: application/x-ndjson' -XPOST 'localhost:9200/shakespeare/_bulk?pretty' --data-binary @shakespeare.json
```

### field collapse
```
GET /shakespeare/_search
{
  "query": {
    "match": {
      "type": "line"
    }
  },
  "profile": true,
  "collapse": {
    "field": "speaker",
    "inner_hits": {
      "name": "speaker_group",
      "size": 3,
      "sort": [{ "line_id": "asc" }]
    }
  },
  "sort": [{ "line_id": "desc" }]
}

```

## Aggregation

### Set return size
```
GET shakespeare/_search
{
  "query": {
    "bool": {
      "filter": {
        "term": {
          "type": "line"
        }
      }
    }
  },
  "aggs": {
    "speaker": {
      "terms": {
        "field": "speaker"
      }
    }
  }
}

GET shakespeare/_search
{
  "size": 0, 
  "query": {
    "bool": {
      "filter": {
        "term": {
          "type": "line"
        }
      }
    }
  },
  "aggs": {
    "speaker": {
      "terms": {
        "field": "speaker"
      }
    }
  }
}
```

### Term Aggregation
Attention: doc size is not always accurate
 - doc_count_error_upper_bound
 - sum_other_doc_count

```
GET shakespeare/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": {
        "term": {
          "type": "line"
        }
      }
    }
  },
  "aggs": {
    "speaker": {
      "terms": {
        "field": "speaker",
        "size": 1000
      }
    }
  }
}
```

### Nested Term Aggregation
```
GET shakespeare/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": {
        "term": {
          "type": "line"
        }
      }
    }
  },
  "aggs": {
    "play_names": {
      "terms": {
        "field": "play_name",
        "size": 10
      },
      "aggs": {
        "play_speaker": {
          "terms": {
            "field": "speaker"
          }
        }
      }
    }
  }
}
```

### Date Range
```
GET top_rated_movies/_search
{
  "size": 0,
  "aggs": {
    "range": {
      "date_range": {
        "field": "release_date",
        "format": "MM-yyy",
        "ranges": [
          {
            "to": "now-5y"
          },
          {
            "from": "now-5y"
          }
        ]
      }
    }
  }
}
```

### Date Histogram
```
GET top_rated_movies/_search
{
    "size": 0,
    "aggs" : {
        "articles_over_time" : {
            "date_histogram" : {
                "field" : "release_date",
                "calendar_interval" : "year",
                "format" : "yyyy" 
            }
        }
    }
}
```

### Annual movies votes
```
GET top_rated_movies/_search
{
    "size" : 0,
    "aggs" : {
        "movies_per_year" : {
            "date_histogram" : {
                "field" : "release_date",
                "calendar_interval" : "year",
                "format": "yyyy"
            },
            "aggs": {
                "votes": {
                    "sum": {
                        "field": "vote_count"
                    }
                }
            }
        }
    }
}
```

### Pipeline Aggregation - Annual movies votes + Average
```
GET top_rated_movies/_search
{
    "size" : 0,
    "aggs" : {
        "movies_per_year" : {
            "date_histogram" : {
                "field" : "release_date",
                "calendar_interval" : "year",
                "format": "yyyy"
            },
            "aggs": {
                "votes": {
                    "sum": {
                        "field": "vote_count"
                    }
                }
            }
        },
        "avg_annual_votes": {
            "avg_bucket": {
                "buckets_path": "movies_per_year>votes" 
            }
        }
    }
}
```

## Go To Production

```
GET /_nodes/process?pretty

GET /_nodes/stats?pretty

GET /_stats
```

## ELK Example

### Index Mapping for Apache Access Log

```
{
  "mappings": {
    "properties": {
      "@timestamp": {
        "type": "date"
      },
      "auth": {
        "type": "keyword"
      },
      "bytes": {
        "type": "long"
      },
      "clientip": {
        "type": "ip"
      },
      "geoip": {
        "properties": {
          "city_name": {
            "type": "keyword"
          },
          "continent_name": {
            "type": "keyword"
          },
          "country_iso_code": {
            "type": "keyword"
          },
          "country_name": {
            "type": "keyword"
          },
          "location": {
            "type": "geo_point"
          },
          "region_iso_code": {
            "type": "keyword"
          },
          "region_name": {
            "type": "keyword"
          }
        }
      },
      "httpversion": {
        "type": "keyword"
      },
      "ident": {
        "type": "keyword"
      },
      "request": {
        "type": "text",
        "fields": {
          "keyword": {
            "type": "keyword",
            "ignore_above": 256
          }
        }
      },
      "response": {
        "type": "keyword",
        "fields": {
          "integer": {
            "type": "integer"
          }
        }
      },
      "timestamp": {
        "type": "date",
        "format" : "DD/MMM/YYYY:HH:mm:SS Z"
      },
      "verb": {
        "type": "keyword"
      }
    }
  }
}
```

### Test Grok Pattern

```
64.242.88.10 - - [08/Mar/2004:00:27:53 -0800] "GET /twiki/bin/view/TWiki/GoBox HTTP/1.1" 200 3762
```

```
%{COMMONAPACHELOG}
```


```
joe 64.242.88.10 - - [08/Mar/2004:00:27:53 -0800] "GET /twiki/bin/view/TWiki/GoBox HTTP/1.1" 200 3762
```

```
%{USERNAME:username} %{COMMONAPACHELOG}
```
