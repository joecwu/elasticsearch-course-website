docker run --name nginx --restart=always -p 80:80 -v /opt/nginx/nginx.conf:/etc/nginx/nginx.conf:ro -v /opt/es-course:/usr/share/nginx/es-course -v /opt/nginx/logs:/var/nginx/logs -d nginx
