docker run --name nginx --restart=always -p 80:80 -v /mnt/elasticsearch-course-website/nginx/nginx.conf:/etc/nginx/nginx.conf:ro -v /mnt/elasticsearch-course-website/es-course:/usr/share/nginx/es-course -v /mnt/elasticsearch-course-website/nginx/logs:/var/nginx/logs -d nginx