# Elasticsearch Training Material

## ELASTICSEARCH 快速上手

### 查詢 Cluster 狀態

```
GET _cat/nodes?v
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

## Elasticsearch Under the Hood

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
# For Day 2
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
            "type": "edgeNGram",
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


# 補充，混合 拼音 與 IK analyzer
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
   "user": [
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

```
PUT _index_template/my_template
{
  "index_patterns": [
    "joe-*",
    "喬-*"
  ],
  "template": {
    "settings": {
      "number_of_shards": 1
    },
    "mappings": {
      "_source": {
        "enabled": false
      },
      "properties": {
        "id": {
          "type": "keyword"
        }
      }
    }
  }
}

POST joe-yoyo/_doc/1
{
  "id":"hi hi hi",
  "name":"yo yo yo"
}

GET joe-yoyo/_mapping
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
                "interval" : "year",
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
                "interval" : "year",
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
