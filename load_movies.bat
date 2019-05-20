@echo off

curl -XDELETE "localhost:9200/movies" & echo.
echo "Index movies deleted" & echo.

curl -XPUT "localhost:9200/movies/_doc/1" -d "{\"title\": \"Interstellar\", \"director\": \"Christopher Nolan\", \"year\": 2014, \"genres\": [\"Adventure\", \"Sci-Fi\"]}" & echo.
curl -XPUT "localhost:9200/movies/_doc/2" -d "{\"title\": \"The Dark Knight\", \"director\": \"Christopher Nolan\",\"year\": 2008,\"genres\": [\"Action\", \"Crime\", \"Drama\"]}" & echo.
curl -XPUT "localhost:9200/movies/_doc/3" -d "{\"title\": \"Lawrence of Arabia\", \"director\": \"David Lean\", \"year\": 1962, \"genres\": [\"Adventure\", \"Biography\", \"Drama\"]}" & echo.
curl -XPUT "localhost:9200/movies/_doc/4" -d "{\"title\": \"To Kill a Mockingbird\", \"director\": \"Robert Mulligan\", \"year\": 1962, \"genres\": [\"Crime\", \"Drama\", \"Mystery\"]}" & echo.
curl -XPUT "localhost:9200/movies/_doc/5" -d "{\"title\": \"Apocalypse Now\", \"director\": \"Francis Ford Coppola\", \"year\": 1979, \"genres\": [\"Drama\", \"War\"]}" & echo.
curl -XPUT "localhost:9200/movies/_doc/6" -d "{\"title\": \"Kill Bill: Vol. 1\", \"director\": \"Quentin Tarantino\", \"year\": 2003, \"genres\": [\"Action\", \"Crime\", \"Thriller\"]}" & echo.
curl -XPUT "localhost:9200/movies/_doc/7" -d "{\"title\": \"The Assassination of Jesse James by the Coward Robert Ford\", \"director\": \"Andrew Dominik\", \"year\": 2007, \"genres\": [\"Biography\", \"Crime\", \"Drama\"]}" & echo.
echo "All documents indexed."

timeout 1 > NUL
echo.
curl -XGET "localhost:9200/_cat/indices?v"

