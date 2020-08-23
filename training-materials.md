# Elasticsearch Training Material

## Setup Elasticsearch

```
GET _cat/nodes?v

PUT /movies/_doc/1
{
  "title": "Star Wars: Episode VII – The Force Awakens",
  "director": "J.J. Abrams",
  "year": 2015
}

GET _cat/indices?v

GET _cat

GET _search

PUT /movies/_doc/1
{
  "title": "Star Wars: Episode VII – The Force Awakens",
  "director": "J.J. Abrams",
  "year": 2015,
  "genres": ["Action", "Adventure", "Fantasy"]
}

PUT /movies/_doc/2
{
    "title": "The Godfather",
    "director": "Francis Ford Coppola",
    "year": 1972,
    "genres": ["Crime", "Drama"]
}

PUT /movies/_doc/3
{
    "title": "Kill Bill: Vol. 1",
    "director": "Quentin Tarantino",
    "year": 2003,
    "genres": ["Action", "Crime", "Thriller"]
}

GET /movies/_doc/1

GET /movies/_doc/1?_source=title,director

GET /movies/_doc/1/_source

DELETE /movies/_doc/1
```

## Search

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

# Filter

POST /movies/_search
{
    "query": {
        "bool": {
            "must": [
                {
                    "range": {
                       "year": {
                          "from": 1972
                       }
                    }
                }
            ], 
            "filter": [
                {
                    "term": {
                        "genres": "crime"
                    }
                }
            ]
        }
    }
}

POST /movies/_search
{
    "query": {
        "bool": {
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

## Mapping

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

```

# Create Index
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

# Indexing Document
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

# Get API

GET /movies/_doc/1

# Exists API

HEAD /movies/_doc/1

# Delete API

DELETE /movies/_doc/1

# Delete by Query API

POST /movies/_delete_by_query
{
  "query": { "match_all": {} } 
}

# Update API

POST /movies/_update/1
{
  "doc":{
    "likes": 123
  }
}

# Multi Get API

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

# Bulk API

curl -i -XPUT http://localhost:9200/_bulk -H 'Content-Type: application/json' --data-binary @top_rated.json

curl -i -XPUT http://localhost:9200/shakespeare/_bulk -H 'Content-Type: application/x-ndjson' --data-binary @shakespeare.json

or

PUT /_bulk
{{content of top_rated.json}}

# Search API

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

## Segments
```
  GET /_cat/indices?v

  GET /_cat/segments?v

  POST /_forcemerge?max_num_segments=1
```


---
# For Day 2
---

## Analyzer
```
POST /_analyze
{
  "tokenizer": "keyword", 
  "text": "New York"
}

POST /_analyze
{
  "tokenizer": "keyword", 
  "filter": [ "lowercase", "stop" ],
  "text": "New York"
}

POST /_analyze
{
  "tokenizer": "whitespace", 
  "filter": [ "lowercase", "stop" ],
  "text": "The New York city is a big city"
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

PUT /courses
{
  "settings": {
    "index": {
      "analysis": {
        "analyzer": {
          "custom_analyzer": {
            "tokenizer": "lowercase",
            "filter": [
              "lowercase",
              "stop",
              "snowball"
            ]
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
        "analyzer": "custom_analyzer"
      }
    }
  }
}

#Deprecated since 6.0
GET /courses/_analyze?field=_doc.title&text=test for customized analyzer

POST /courses/_analyze
{
  "field": "title", 
  "text": "test for customized analyzer"
}

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
              "lowercase",
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
        "store": true,
        "index": true,
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

#pinyin 拼音plugin

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

# IK Analyzer Install

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


# 補充 混合analyzer

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

## Mapping

### Store
```
DELETE /my_index

PUT /my_index
{
  "settings":{
    "refresh_interval": "1s"
  },
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
  "settings":{
    "refresh_interval": "1s"
  },
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
PUT _template/my_template
{
  "index_patterns": [
    "joe-*",
    "*-wu"
  ],
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

POST joe-yoyo/_doc/1
{
  "id":"hi hi hi",
  "name":"yo yo yo"
}

GET joe-yoyo/_mapping
```


## Search

### match query with `type`

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

# unable to find by using phrase match
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
  "time": "2017-03-05T23:12:13"
}

PUT test_date/_doc/2
{
  "time": "2017-03-05"
}

PUT test_date/_doc/3
{
  "time": "2017-03-05T00:00:00"
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
            "lt": "2018-03-05",
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



## DEBUG
```
GET movies/movie/1/_explain
{
    "query": {
        "match": {
           "title": {
               "type": "boolean",
               "query": "Star Wars: Episode VII – The Force Awakens",
               "minimum_should_match": "28%"
           }
        }
    }
}

```

## Others

```
GET /movies/_segments?pretty

GET /courses/_settings

GET /_nodes/process?pretty

GET /_nodes/stats?pretty
```

## ELK Example

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

###


## Sample Data
### Movies (for cURL)

```
curl -XPUT "localhost:9200/movies/_cat/4" -d "{\"title\": \"To Kill a Mockingbird\", \"director\": \"Robert Mulligan\", \"year\": 1962, \"genres\": [\"Crime\", \"Drama\", \"Mystery\"]}"
curl -XPUT "localhost:9200/movies/_cat/5" -d "{\"title\": \"Apocalypse Now\", \"director\": \"Francis Ford Coppola\", \"year\": 1979, \"genres\": [\"Drama\", \"War\"]}"
curl -XPUT "localhost:9200/movies/_cat/6" -d "{\"title\": \"Kill Bill: Vol. 1\", \"director\": \"Quentin Tarantino\", \"year\": 2003, \"genres\": [\"Action\", \"Crime\", \"Thriller\"]}"
curl -XPUT "localhost:9200/movies/_cat/7" -d "{\"title\": \"The Assassination of Jesse James by the Coward Robert Ford\", \"director\": \"Andrew Dominik\", \"year\": 2007, \"genres\": [\"Biography\", \"Crime\", \"Drama\"]}"
curl -XPUT "localhost:9200/movies/_cat/8" -d "{\"title\": \"Interstellar\", \"director\": \"Christopher Nolan\", \"year\": 2014, \"genres\": [\"Adventure\", \"Sci-Fi\"]}"
curl -XPUT "localhost:9200/movies/_cat/9" -d "{\"title\": \"The Dark Knight\", \"director\": \"Christopher Nolan\",\"year\": 2008,\"genres\": [\"Action\", \"Crime\", \"Drama\"]}"
curl -XPUT "localhost:9200/movies/_cat/10" -d "{\"title\": \"Lawrence of Arabia\", \"director\": \"David Lean\", \"year\": 1962, \"genres\": [\"Adventure\", \"Biography\", \"Drama\"]}"

```

### Movies (for Kibana Dev Tools)

```
PUT movies/_doc/1
{"title":"Star Wars: Episode VII – The Force Awakens","director":"J.J. Abrams","year":2015,"genres":["Action","Adventure","Fantasy"]}

PUT movies/_doc/2
{"title":"The Godfather","director":"Francis Ford Coppola","year":1972,"genres":["Crime","Drama"]}

PUT movies/_doc/3
{"title":"Kill Bill: Vol. 1","director":"Quentin Tarantino","year":2003,"genres":["Action","Crime","Thriller"]}

PUT movies/_doc/4
{"title":"To Kill a Mockingbird","director":"Robert Mulligan","year":1962,"genres":["Crime","Drama","Mystery"]}

PUT movies/_doc/5
{"title":"Apocalypse Now","director":"Francis Ford Coppola","year":1979,"genres":["Drama","War"]}

PUT movies/_doc/6
{"title":"Kill Bill: Vol. 1","director":"Quentin Tarantino","year":2003,"genres":["Action","Crime","Thriller"]}

PUT movies/_doc/7
{"title":"The Assassination of Jesse James by the Coward Robert Ford","director":"Andrew Dominik","year":2007,"genres":["Biography","Crime","Drama"]}

PUT movies/_doc/8
{"title":"Interstellar","director":"Christopher Nolan","year":2014,"genres":["Adventure","Sci-Fi"]}

PUT movies/_doc/9
{"title":"The Dark Knight","director":"Christopher Nolan","year":2008,"genres":["Action","Crime","Drama"]}

PUT movies/_doc/10
{"title":"Lawrence of Arabia","director":"David Lean","year":1962,"genres":["Adventure","Biography","Drama"]}
```