# 課程範例 v2

## Account 宣告 mapping 與不宣告的 size 差異

### 不指定 mapping

```
PUT account_v1
{paste from https://es.joecwu.com/accounts.json}
```

### 檢視 Mapping

```
GET account_v1/_mapping
```

### 指定 mapping

```
PUT account_v2
{
  "settings": {},
  "mappings": {
    "properties": {
      "account_number": {
        "type": "integer"
      },
      "balance": {
        "type": "integer"
      },
      "firstname": {
        "type": "keyword"
      },
      "lastname": {
        "type": "keyword"
      },
      "age": {
        "type": "integer"
      },
      "gender": {
        "type": "keyword"
      },
      "address": {
        "type": "text"
      },
      "employer": {
        "type": "keyword"
      },
      "email": {
        "type": "keyword"
      },
      "city": {
        "type": "keyword"
      },
      "state": {
        "type": "keyword"
      }
    }
  }
}
```

```
PUT account_v2
{paste from https://es.joecwu.com/accounts.json}
```

### 檢查兩者的差異

```
GET _cat/indices?v&index=account*
```

### 使用 Dynamic Template

```
PUT account_v2
{
  "settings": {},
  "mappings": {
    "dynamic_templates": [
      {
        "strings_as_keyword": {
          "match_mapping_type": "string",
          "mapping": {
            "type": "keyword"
          }
        }
      }
    ],
    "properties": {
      "account_number": {
        "type": "integer"
      },
      "balance": {
        "type": "integer"
      },
      "age": {
        "type": "integer"
      },
      "address": {
        "type": "text"
      }
    }
  }
}
```


### 使用 Index Template + Dynamic Mapping

```
PUT _index_template/account
{
  "version": 1,
  "index_patterns": [
    "account_*"
  ],
  "template": {
    "settings": {},
    "mappings": {
      "dynamic_templates": [
        {
          "strings_as_keyword": {
            "match_mapping_type": "string",
            "mapping": {
              "type": "keyword"
            }
          }
        }
      ],
      "properties": {
        "account_number": {
          "type": "integer"
        },
        "balance": {
          "type": "integer"
        },
        "age": {
          "type": "integer"
        },
        "address": {
          "type": "text"
        }
      }
    },
    "aliases": {
      "account": {}
    }
  },
  "_meta": {
    "last_modified_date": "2021-05-26",
    "desc": "Demo"
  }
}
```

## Deleted Docs & Refresh & Flush & Segment Files 的變化與 Disk size 的差異

```
# 使用先前的 _bulk

GET _cat/indices?v&index=account*

POST account_v1/_refresh
POST account_v2/_refresh
POST account_v2/_flush

POST account_v2/_forcemerge?max_num_segments=1
```


## Find Structure

```
curl -s -H "Content-Type: application/json" -XPOST "localhost:9200/_text_structure/find_structure?pretty" -T "./top_rated_movies.en_US.bulk"
```


## Ingest Pipeline

### Movie Director

Source Index

```
PUT director
{
  "settings": {
    "number_of_shards": 1
  },
  "mappings": {
    "properties": {
      "name": {
        "type": "keyword"
      },
      "age": {
        "type": "integer"
      }
    }
  }
}
```

Sample Data

```
PUT director/_doc/1
{
  "name": "J.J. Abrams",
  "age": 67
}

PUT director/_doc/2
{
  "name": "Francis Ford Coppola",
  "age": 33
}
```

Enrich Policy

```
PUT /_enrich/policy/movie-director
{
  "match": {
    "indices": "director",
    "match_field": "name",
    "enrich_fields": ["name", "age"]
  }
}

GET /_enrich/policy

PUT /_enrich/policy/movie-director/_execute?wait_for_completion=true
```

Enrich Index

```
GET _cat/indices/.enrich-*?v

GET .enrich-*/_search
```


Enrich Pipeline Processor

```
POST _ingest/pipeline/_simulate
{
  "pipeline": {
    "processors": [
      {
        "enrich": {
          "policy_name": "movie-director",
          "field": "director",
          "target_field": "director_info"
        }
      }
    ]
  },
  "docs": [
    {
      "_index": "movies",
      "_type": "_doc",
      "_id": "1",
      "_score": 1,
      "_source": {
        "title": "Star Wars: Episode VII – The Force Awakens",
        "director": "J.J. Abrams",
        "year": 2015,
        "genres": [
          "Action",
          "Adventure",
          "Fantasy"
        ]
      }
    },
    {
      "_index": "movies",
      "_type": "_doc",
      "_id": "2",
      "_score": 1,
      "_source": {
        "title": "The Godfather",
        "director": "Francis Ford Coppola",
        "year": 1972,
        "genres": [
          "Crime",
          "Drama"
        ]
      }
    },
    {
      "_index": "movies",
      "_type": "_doc",
      "_id": "3",
      "_score": 1,
      "_source": {
        "title": "Kill Bill: Vol. 1",
        "director": "Quentin Tarantino",
        "year": 2003,
        "genres": [
          "Action",
          "Crime",
          "Thriller"
        ]
      }
    }
  ]
}
```


Enrich Stats

```
GET /_enrich/_stats
```








